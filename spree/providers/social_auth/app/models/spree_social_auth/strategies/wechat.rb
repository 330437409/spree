module SpreeSocialAuth
  module Strategies
    # WeChat Open Platform website application login (网站应用微信登录).
    class WeChat < Oauth2Strategy
      AUTHORIZE_URL = 'https://open.weixin.qq.com/connect/qrconnect'.freeze
      TOKEN_URL = 'https://api.weixin.qq.com/sns/oauth2/access_token'.freeze
      PROFILE_URL = 'https://api.weixin.qq.com/sns/userinfo'.freeze

      # WeChat returns no email, which is why the registration step exists.
      def self.provider(key: :wechat, label: 'WeChat', integration_class: SpreeSocialAuth::Integrations::WeChat)
        super(key: key, label: label, integration_class: integration_class, requires_email: true)
      end

      # The fragment is mandatory, and it must stay last.
      def authorization_url(state:)
        "#{super}#wechat_redirect"
      end

      private

      def authorize_url
        AUTHORIZE_URL
      end

      def authorize_params(state:)
        {
          appid: integration.preferred_client_id,
          redirect_uri: redirect_uri,
          response_type: 'code',
          scope: 'snsapi_login',
          state: state
        }
      end

      def token_url
        TOKEN_URL
      end

      def token_params(code:)
        {
          appid: integration.preferred_client_id,
          secret: integration.preferred_client_secret,
          code: code,
          grant_type: 'authorization_code'
        }
      end

      def profile_url
        PROFILE_URL
      end

      def profile_params(token)
        {
          access_token: token['access_token'],
          openid: token['openid'],
          lang: 'zh_CN'
        }
      end

      # WeChat answers failures with HTTP 200 and an errcode in the body, so the
      # body decides success — never the status.
      def check_errors!(payload)
        code = payload['errcode']
        return payload if code.blank? || code.to_i.zero?

        raise SpreeSocialAuth::ApiError.new(explain(code.to_s, payload['errmsg']), code: code.to_s)
      end

      # A spent code is the shopper's to retry; rejected credentials are the
      # merchant's to fix, and saying which saves a support round trip.
      def explain(code, message)
        case code
        when '40029', '40163', '42003'
          "The WeChat authorization code was no longer usable (#{message}). A code is single use and expires after ten minutes, so the shopper needs to start again."
        when '40013', '40001', '40125', '41002', '41004', '41008'
          "WeChat rejected the application credentials (#{message}). Check that the AppID and AppSecret belong to the same account."
        when '-1'
          "WeChat was too busy to answer (#{message}). Try again."
        else
          message.presence || 'WeChat refused the sign-in.'
        end
      end

      # One person, one account: a unionid identifies them across every app bound
      # to the same Open Platform account, while an openid only means something
      # inside this one app.
      def normalize_profile(token, profile)
        openid = profile['openid'].presence || token['openid']
        unionid = profile['unionid'].presence || token['unionid']

        Spree::Authentication::Profile.new(
          provider: provider,
          uid: unionid.presence || openid,
          email: nil,
          email_verified: nil,
          info: {
            'nickname' => profile['nickname'],
            'avatar_url' => profile['headimgurl'],
            'openid' => openid,
            'unionid' => unionid
          },
          tokens: {
            access_token: token['access_token'],
            refresh_token: token['refresh_token'],
            expires_at: expires_at(token)
          }
        )
      end

      def expires_at(token)
        seconds = token['expires_in'].to_i
        seconds.positive? ? Time.current + seconds.seconds : nil
      end
    end
  end
end
