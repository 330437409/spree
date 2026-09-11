module SpreeSocialAuth
  module Integrations
    # Douyin Open Platform (抖音开放平台) website application login.
    #
    # The client key and secret belong to an approved website application, and
    # the console registers the callback domain the redirect must sit under.
    class Douyin < Integration
      def self.description
        'Sign in with Douyin'
      end

      # Douyin rejects a callback URL that carries a query string, and says so
      # only when a shopper tries to sign in — so it is checked at activation.
      def can_connect?
        return false unless super
        return true if URI.parse(preferred_redirect_uri.to_s).query.blank?

        self.connection_error_message = Spree.t('spree_social_auth.errors.redirect_uri_must_not_have_query')
        false
      rescue URI::InvalidURIError
        self.connection_error_message = Spree.t('spree_social_auth.errors.credentials_missing')
        false
      end
    end
  end
end
