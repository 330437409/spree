module SpreeSocialAuth
  # Per-store credentials for one social provider.
  #
  # Every provider subclass declares the same settings, so the dashboard's
  # Integrations page renders one card per provider under a shared group, and a
  # shopper never sees a provider this store has not configured.
  class Integration < Spree::Integration
    preference :client_id, :string
    preference :client_secret, :password
    # The callback URL registered with the provider for this store. Both halves
    # of the flow use it: a provider rejects a token exchange whose
    # redirect_uri differs from the authorization request's.
    preference :redirect_uri, :string
    # Only for a provider whose directory owns the addresses it issues. Never
    # for one where a person chooses their own email.
    preference :trust_unverified_email, :boolean, default: false

    def self.integration_group
      'authentication'
    end

    # A tracked `active` flip runs this. WeChat, Douyin and QQ publish no cheap
    # unauthenticated endpoint, so presence is all that can be checked here;
    # the first shopper login is what proves the secret.
    def can_connect?
      return true if preferred_client_id.present? && preferred_client_secret.present? && preferred_redirect_uri.present?

      self.connection_error_message = Spree.t('spree_social_auth.errors.credentials_missing')
      false
    end
  end
end
