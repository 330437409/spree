module Spree
  module Api
    module V3
      # Signed, self-expiring OAuth state shared by the surfaces that complete a
      # browser redirect: the admin dashboard's SSO callback and the
      # storefront's social login.
      #
      # Signing it means no server-side session storage — the token proves the
      # redirect started here, and a forged or expired value fails verification.
      # The payload binds the provider, and where the surface has one, the store,
      # so a state minted for one provider or store cannot complete on another's
      # callback.
      module OauthState
        extend ActiveSupport::Concern

        OAUTH_STATE_EXPIRY = 15.minutes

        private

        # Each surface signs with its own purpose, so an admin state cannot
        # complete a storefront login, or the other way round.
        # @return [String]
        def oauth_state_purpose
          raise NotImplementedError, "#{self.class} must implement #oauth_state_purpose"
        end

        # @param provider [String, Symbol]
        # @param store [Spree::Store, nil]
        # @return [String] the state parameter for the authorization URL
        def issue_oauth_state(provider, store: nil)
          payload = { provider: provider.to_s, nonce: SecureRandom.hex(16) }
          payload[:store_id] = store.id if store

          Rails.application.message_verifier(oauth_state_purpose).generate(payload, expires_in: OAUTH_STATE_EXPIRY)
        end

        # +verified+ answers nil for a forged or expired message, which is what
        # makes a bad state a rejected login rather than an exception.
        #
        # @param store [Spree::Store, nil] when given, the state must have been
        #   minted for this store as well
        # @return [Boolean]
        def valid_oauth_state?(store: nil)
          state = params[:state]
          return false if state.blank?

          payload = Rails.application.message_verifier(oauth_state_purpose).verified(state)
          return false unless payload.is_a?(Hash)
          return false unless payload['provider'].to_s == params[:provider].to_s
          return false if store && payload['store_id'].to_s != store.id.to_s

          true
        end
      end
    end
  end
end
