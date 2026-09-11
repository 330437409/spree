module SpreeSocialAuth
  module Strategies
    # Shared OAuth 2.0 authorization-code flow.
    #
    # A subclass declares its endpoints, its parameters, and how the provider's
    # payload becomes a Spree::Authentication::Profile. Everything after that —
    # who is signed in, who is merged with an existing account, who still needs
    # an email — is core's resolution, so every provider behaves the same way.
    class Oauth2Strategy < Spree::Authentication::Strategies::BaseStrategy
      class << self
        def kind
          :redirect
        end

        # The registry entry for this provider.
        #
        # @return [SpreeSocialAuth::Provider]
        def provider(key:, label:, integration_class:, requires_email: false)
          SpreeSocialAuth::Provider.new(
            key: key,
            label: label,
            strategy_class: self,
            integration_class: integration_class,
            requires_email: requires_email
          )
        end
      end

      attr_reader :provider_key, :integration

      def initialize(params:, request_env:, user_class: nil, provider: nil, integration: nil)
        super(params: params, request_env: request_env, user_class: user_class)
        @provider_key = provider
        @integration = integration
      end

      def provider
        provider_key
      end

      def trust_unverified_email
        integration&.preferred_trust_unverified_email.present?
      end

      def authorization_url(state:)
        "#{authorize_url}?#{authorize_params(state: state).to_query}"
      end

      # Completes the login the storefront started: exchange the code, read the
      # profile, and hand the identity to core's resolution rules.
      #
      # @return [Spree::ServiceModule::Result]
      def callback
        return failure(Spree.t('spree_social_auth.errors.missing_code')) if params[:code].blank?
        return failure(Spree.t('spree_social_auth.errors.provider_unavailable')) if integration.nil?
        return failure(Spree.t('spree_social_auth.errors.redirect_uri_mismatch')) unless redirect_uri_matches?

        profile = normalize_profile(*exchange(params[:code]))

        # Nothing may touch the database with half an identity: an account
        # created for a profile with no uid would be orphaned by the identity
        # that could not be attached to it.
        unless profile.valid?
          return failure(
            Spree.t('spree_social_auth.errors.identity_incomplete', errors: profile.errors.full_messages.to_sentence)
          )
        end

        resolution = resolve_account(profile)

        return success(resolution.user) if resolution.authenticated?
        return registration_required(profile) if resolution.registration_required?

        failure(failure_message(resolution))
      rescue SpreeSocialAuth::ApiError, SpreeSocialAuth::ConnectionError => e
        log_failure(e)
        failure(e.message)
      rescue ActiveRecord::RecordInvalid => e
        log_failure(e)
        failure(e.record.errors.full_messages.to_sentence.presence || Spree.t('spree_social_auth.errors.authentication_failed'))
      end

      private

      # The shopper can act on a taken address or a shop policy that refused
      # the sign-up; anything else is ours. Naming the reason saves a support
      # round trip.
      def failure_message(resolution)
        return Spree.t('errors.messages.email_taken') if resolution.email_taken?
        return resolution.message if resolution.message.present?

        Spree.t('spree_social_auth.errors.authentication_failed')
      end

      # One line naming the provider, the store and the provider's own code, so
      # a merchant can see why sign-ins fail without reading a 500.
      def log_failure(error)
        code = error.respond_to?(:code) ? error.code : error.class.name
        Rails.logger.warn(
          "[spree_social_auth] #{provider} sign-in failed for store #{Spree::Current.store&.id}: #{code} — #{error.message}"
        )
      end

      # The merchant's registered callback, never a value chosen by the caller:
      # the provider requires the two halves of the flow to match, and relaying
      # a foreign redirect_uri is how an authorization code ends up somewhere
      # the merchant did not intend.
      def redirect_uri
        integration.preferred_redirect_uri
      end

      def redirect_uri_matches?
        return true if params[:redirect_uri].blank?

        params[:redirect_uri] == redirect_uri
      end

      def exchange(code)
        token = unwrap(
          check_errors!(fetch(token_url, token_params(code: code), request: token_request, headers: token_headers))
        )
        profile = unwrap(
          check_errors!(fetch(profile_url, profile_params(token), request: profile_request, headers: profile_headers(token)))
        )

        [token, profile]
      end

      def fetch(url, params, request:, headers:)
        request == :post ? client.post(url, params, headers: headers) : client.get(url, params, headers: headers)
      end

      def client
        @client ||= SpreeSocialAuth::Client.new
      end

      # Headers the exchange needs. WeChat and Douyin carry everything in the
      # parameters; Google puts its access token in a header on the profile read.
      def token_headers
        {}
      end

      def profile_headers(_token)
        {}
      end

      # Providers that refuse with an HTTP status need nothing here; WeChat and
      # Douyin answer 200 with a code in the body and override this.
      def check_errors!(payload)
        payload
      end

      # Providers that wrap their payload in an envelope override this to hand
      # the rest of the flow the part it cares about; the rest get the body.
      def unwrap(payload)
        payload
      end

      # Subclass surface. A provider declares where to send the browser, where
      # to exchange the code, where to read the profile, and what those payloads
      # mean.
      def authorize_url
        raise NotImplementedError
      end

      def authorize_params(state:)
        raise NotImplementedError
      end

      def token_url
        raise NotImplementedError
      end

      def token_params(code:)
        raise NotImplementedError
      end

      def token_request
        :get
      end

      def profile_url
        raise NotImplementedError
      end

      def profile_params(token)
        raise NotImplementedError
      end

      def profile_request
        :get
      end

      def normalize_profile(token, profile)
        raise NotImplementedError
      end
    end
  end
end
