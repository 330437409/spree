module Spree
  module Api
    module V3
      module Store
        module Customer
          # The wallet: the cards this customer bought or was granted, and what
          # each of them is waiting for.
          #
          # Every card here is the signed-in customer's own, addressed by its
          # id. A card on its way to somebody else is reached through the
          # transfer that carries it, which is a token rather than this.
          class MembershipCardsController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def model_class
              Spree::MembershipCard
            end

            def serializer_class
              Spree::Api::V3::MembershipCardSerializer
            end

            def scope
              super.for_customer(current_user)
            end

            # Nothing here joins, so the base's SELECT DISTINCT buys nothing —
            # and it would refuse the sort below on PostgreSQL, which is the one
            # adapter that rejects an ORDER BY the select list does not carry.
            def collection_distinct?
              false
            end

            # Dormant first, because what the wallet is for is activating one.
            def apply_collection_sort(collection)
              collection.order(Arel.sql("status = 'dormant' DESC"), :id)
            end

            def collection_includes
              [{ tier_setting: :published_rights }, :membership, :pending_transfer]
            end

            def scope_includes
              collection_includes
            end
          end
        end
      end
    end
  end
end
