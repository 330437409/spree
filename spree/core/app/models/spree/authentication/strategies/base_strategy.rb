module Spree
  module Authentication
    module Strategies
      class BaseStrategy
        attr_reader :params, :request_env, :user_class

        class << self
          # How a client initiates login with this strategy.
          #
          # +:password+ — the client posts credentials to the auth endpoint.
          # +:redirect+ — the client sends the browser to the identity provider,
          # which returns through the OAuth callback.
          #
          # Defaults to +:password+ so strategies written before provider
          # discovery existed keep describing themselves correctly.
          # @return [Symbol]
          def kind
            :password
          end

          # Human-readable provider name for the login button. Only meaningful for
          # +:redirect+ strategies; defaults to nil so password strategies render
          # their standard form instead of a button.
          # @return [String, nil]
          def label
            nil
          end

          # Whether this provider can answer without an email the account needs.
          # Published through provider discovery so the storefront can say a
          # registration step is coming. Password strategies never ask.
          # @return [Boolean]
          def requires_email
            false
          end
        end

        def initialize(params:, request_env:, user_class: nil)
          @params = params
          @request_env = request_env
          @user_class = user_class || Spree.customer_class
        end

        # Whether this provider's email claim may be trusted to adopt an
        # existing account when the provider does not assert verification.
        # Off by default, and only an integration for a directory that owns the
        # addresses it issues should turn it on.
        # @return [Boolean]
        def trust_unverified_email
          false
        end

        # The profile of a shopper who authenticated but whose account still
        # needs an email, set by +#registration_required+.
        # @return [Spree::Authentication::Profile, nil]
        attr_reader :registration_profile

        # True when the last +#callback+ authenticated the shopper but stopped
        # short of an account because the provider returned no email. The
        # controller answers with a registration token instead of a session.
        # @return [Boolean]
        def registration_required?
          registration_profile.present?
        end

        # Where to send the browser to begin authentication. Redirect strategies
        # must implement this; password strategies never call it.
        #
        # @param state [String] opaque CSRF token echoed back to the callback
        # @return [String] the identity provider's authorization URL
        def authorization_url(state:)
          raise NotImplementedError, 'Redirect strategies must implement #authorization_url'
        end

        # Completes a redirect login from the identity provider's callback params.
        # Redirect strategies must implement this; password strategies use
        # +#authenticate+ instead.
        #
        # @return [Spree::ServiceModule::Result] the resolved user on success
        def callback
          raise NotImplementedError, 'Redirect strategies must implement #callback'
        end

        # Returns Result object with user on success
        # @return [Spree::ServiceModule::Result]
        def authenticate
          raise NotImplementedError, 'Subclass must implement #authenticate'
        end

        # Returns provider identifier (e.g., 'google', 'email')
        # @return [String]
        def provider
          raise NotImplementedError, 'Subclass must implement #provider'
        end

        protected

        # Success result with user
        def success(user)
          Spree::ServiceModule::Result.new(success: true, value: user)
        end

        # Failure result with error message
        def failure(message)
          Spree::ServiceModule::Result.new(success: false, error: message)
        end

        # Looks a user up by email, case-insensitively.
        #
        # The models validate email uniqueness with +case_sensitive: false+ but
        # normalize with +squish+ only, so a stored "Ada@Example.com" is the same
        # account as "ada@example.com" — an exact match would refuse login to
        # someone who capitalizes their own address differently.
        #
        # @param email [String]
        # @return [Object, nil]
        def find_user_by_email(email)
          return nil if email.blank?

          user_class.find_by(user_class.arel_table[:email].lower.eq(email.to_s.downcase))
        end

        # Resolves a provider profile to an account, or reports that one still
        # has to be registered. Strategies call this from +#callback+.
        #
        # @param profile [Spree::Authentication::Profile]
        # @return [Spree::Authentication::Resolution]
        def resolve_account(profile)
          Spree::Authentication::ResolveAccount.new(
            profile: profile,
            store: Spree::Current.store,
            user_class: user_class,
            trust_unverified_email: trust_unverified_email
          ).call
        end

        # Records that the shopper authenticated but the account still needs an
        # email, so the caller can mint a registration token rather than create
        # an account with an address that cannot receive mail.
        #
        # @param profile [Spree::Authentication::Profile]
        # @return [Spree::ServiceModule::Result] a failure, by convention
        def registration_required(profile)
          @registration_profile = profile
          failure(Spree.t('errors.messages.registration_required'))
        end

        # Signs an OAuth profile in through the shared resolution rules.
        #
        # @raise [Spree::Authentication::RegistrationRequired] when the profile
        #   carries no email — call +#registration_required+ instead
        def find_or_create_user_from_oauth(provider:, uid:, info:, tokens: {})
          Spree::UserIdentity.find_or_create_from_oauth(
            provider: provider,
            uid: uid,
            info: info,
            tokens: tokens,
            user_class: user_class
          )
        end
      end
    end
  end
end
