module Spree
  module Authentication
    # What a strategy knows about the person once the provider has answered,
    # normalised so core can resolve it without knowing which provider spoke.
    #
    # +email_verified+ mirrors the provider's own claim and its three states
    # matter: +true+ lets the address claim an existing account, +false+ is
    # always refused, and +nil+ (the provider says nothing) falls to the
    # integration's +trust_unverified_email+ opt-in.
    class Profile
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :provider, :string
      attribute :uid, :string
      attribute :email, :string
      attribute :email_verified, :boolean
      attribute :info, default: -> { {} }
      attribute :tokens, default: -> { {} }

      validates :provider, :uid, presence: true

      # The address allowed to claim an existing account.
      #
      # @param trust_unverified [Boolean] the integration's opt-in for a
      #   provider whose directory owns the addresses it issues
      # @return [String, nil]
      def verified_email(trust_unverified: false)
        return nil if email.blank?
        return nil if email_verified == false
        return email if email_verified

        trust_unverified ? email : nil
      end

      # @param key [Symbol] +:access_token+, +:refresh_token+ or +:expires_at+
      # @return [Object, nil]
      def token(key)
        tokens[key] || tokens[key.to_s]
      end

      # @param key [Symbol]
      # @return [Boolean] whether the provider returned this token at all
      def token?(key)
        tokens.key?(key) || tokens.key?(key.to_s)
      end

      # @return [Hash] payload for the signed registration token
      def to_h
        {
          provider: provider,
          uid: uid,
          email: email,
          email_verified: email_verified,
          info: info,
          tokens: tokens
        }
      end

      # @param payload [Hash] a token payload, whose keys come back as strings
      # @return [Spree::Authentication::Profile]
      def self.from_h(payload)
        new(**payload.to_h.symbolize_keys.slice(:provider, :uid, :email, :email_verified, :info, :tokens))
      end
    end
  end
end
