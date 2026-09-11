module SpreeSocialAuth
  module Strategies
    # Google sign-in, over the standard OAuth 2.0 / OpenID Connect endpoints.
    class Google < Oauth2Strategy
      AUTHORIZE_URL = 'https://accounts.google.com/o/oauth2/v2/auth'.freeze
      TOKEN_URL = 'https://oauth2.googleapis.com/token'.freeze
      PROFILE_URL = 'https://openidconnect.googleapis.com/v1/userinfo'.freeze

      # Google returns the address already marked verified, so a shopper who
      # already has an account here signs into it rather than getting a second.
      def self.provider(key: :google, label: 'Google', integration_class: SpreeSocialAuth::Integrations::Google)
        super(key: key, label: label, integration_class: integration_class, requires_email: false)
      end

      private

      def authorize_url
        AUTHORIZE_URL
      end

      def authorize_params(state:)
        {
          client_id: integration.preferred_client_id,
          redirect_uri: redirect_uri,
          response_type: 'code',
          # `openid` is what makes the userinfo endpoint answer with the standard
          # claims; `email` and `profile` are the ones read below.
          scope: 'openid email profile',
          state: state
        }
      end

      def token_url
        TOKEN_URL
      end

      def token_request
        :post
      end

      # Google requires the redirect_uri on the exchange as well, and rejects a
      # mismatch — the base already uses the merchant's registered one.
      def token_params(code:)
        {
          code: code,
          client_id: integration.preferred_client_id,
          client_secret: integration.preferred_client_secret,
          redirect_uri: redirect_uri,
          grant_type: 'authorization_code'
        }
      end

      def profile_url
        PROFILE_URL
      end

      # No `access_type=offline`: nothing here calls a Google API later, and
      # asking for offline access adds a consent prompt to every sign-in.
      def profile_headers(token)
        { 'Authorization' => "Bearer #{token['access_token']}" }
      end

      def profile_params(_token)
        {}
      end

      # `sub` is Google's stable subject. The address travels with the claim
      # that says whether Google verified it — which is what lets an existing
      # account adopt this identity, and what stops anyone claiming an address
      # they do not own.
      def normalize_profile(token, profile)
        Spree::Authentication::Profile.new(
          provider: provider,
          uid: profile['sub'],
          email: profile['email'],
          email_verified: profile['email_verified'],
          info: {
            'name' => profile['name'],
            'first_name' => profile['given_name'],
            'last_name' => profile['family_name'],
            'avatar_url' => profile['picture'],
            'locale' => profile['locale']
          },
          tokens: {
            access_token: token['access_token'],
            refresh_token: token['refresh_token'],
            expires_at: expires_at(token)
          }.compact
        )
      end

      def expires_at(token)
        seconds = token['expires_in'].to_i
        seconds.positive? ? Time.current + seconds.seconds : nil
      end
    end
  end
end
