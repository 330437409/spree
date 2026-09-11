module SpreeSocialAuth
  module Integrations
    # WeChat Open Platform website application (网站应用微信登录).
    #
    # The AppID and AppSecret belong to an approved Open Platform website
    # application, not to a merchant's payment account — the two are separate
    # WeChat products and their credentials are not interchangeable.
    class WeChat < Integration
      def self.description
        'Sign in with WeChat'
      end
    end
  end
end
