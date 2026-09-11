module SpreeSocialAuth
  module Strategies
    # Douyin Open Platform website application login (抖音开放平台网站授权).
    class Douyin < Oauth2Strategy
      AUTHORIZE_URL = 'https://open.douyin.com/platform/oauth/connect'.freeze
      TOKEN_URL = 'https://open.douyin.com/oauth/access_token/'.freeze
      PROFILE_URL = 'https://open.douyin.com/oauth/userinfo/'.freeze

      # Douyin returns no email, which is why the registration step exists.
      def self.provider(key: :douyin, label: 'Douyin', integration_class: SpreeSocialAuth::Integrations::Douyin)
        super(key: key, label: label, integration_class: integration_class, requires_email: true)
      end

      private

      def authorize_url
        AUTHORIZE_URL
      end

      # Douyin names these client_key and client_secret, not app_id and
      # app_secret, and rejects a redirect_uri carrying a query string.
      def authorize_params(state:)
        {
          client_key: integration.preferred_client_id,
          response_type: 'code',
          scope: 'user_info',
          redirect_uri: redirect_uri,
          state: state
        }
      end

      def token_url
        TOKEN_URL
      end

      def token_request
        :post
      end

      def token_params(code:)
        {
          client_key: integration.preferred_client_id,
          client_secret: integration.preferred_client_secret,
          code: code,
          grant_type: 'authorization_code'
        }
      end

      def profile_url
        PROFILE_URL
      end

      def profile_request
        :post
      end

      def profile_params(token)
        {
          access_token: token['access_token'],
          open_id: token['open_id']
        }
      end

      # Douyin answers failures with HTTP 200, and its two endpoints disagree on
      # where the code lives: OAuth wraps `error_code` in `data`, userinfo puts
      # `err_no` beside it. The body decides success, never the status.
      def check_errors!(payload)
        code = payload['error_code'] || payload.dig('data', 'error_code') ||
               payload['err_no'] || payload.dig('data', 'err_no')

        return payload if code.blank? || code.to_i.zero?

        message = payload['message'].presence || payload['err_msg'].presence ||
                  payload.dig('data', 'description').presence

        raise SpreeSocialAuth::ApiError.new(explain(code.to_s, message), code: code.to_s)
      end

      def unwrap(payload)
        payload['data'] || {}
      end

      def explain(code, message)
        case code
        when '10007'
          "The Douyin authorization code was no longer usable (#{message}). A code is single use and expires after ten minutes, so the shopper needs to start again."
        when '10003', '10013'
          "Douyin rejected the application credentials (#{message}). Check that the client key and client secret belong to the same app."
        when '28001003', '28001008'
          "The Douyin access token was no longer valid (#{message}). The shopper needs to sign in again."
        else
          message.presence || 'Douyin refused the sign-in.'
        end
      end

      # One person, one account: a union_id identifies them across every app
      # under the same developer account, while an open_id only means something
      # inside this one app.
      def normalize_profile(token, profile)
        openid = profile['open_id'].presence || token['open_id']
        unionid = profile['union_id'].presence || token['union_id']

        Spree::Authentication::Profile.new(
          provider: provider,
          uid: unionid.presence || openid,
          email: nil,
          email_verified: nil,
          info: {
            'nickname' => profile['nickname'],
            'avatar_url' => profile['avatar'],
            'openid' => openid,
            'unionid' => unionid
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
