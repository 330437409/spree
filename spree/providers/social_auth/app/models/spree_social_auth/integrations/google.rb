module SpreeSocialAuth
  module Integrations
    # Google identity — the standard OAuth 2.0 / OpenID Connect endpoints.
    #
    # Simpler than the Chinese providers in every respect: the token exchange is
    # a plain form post, the profile read carries a bearer token, refusals come
    # back as real HTTP statuses, and the address is returned already marked
    # verified.
    class Google < Integration
      def self.description
        'Sign in with Google'
      end
    end
  end
end
