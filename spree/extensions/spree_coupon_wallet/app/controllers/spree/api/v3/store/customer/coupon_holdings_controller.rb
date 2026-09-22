module Spree
  module Api
    module V3
      module Store
        module Customer
          # The customer's own wallet: the coupons they hold, one of them, and
          # the way a code they already have enters it — claiming a code the
          # platform texted them or the operator published.
          class CouponHoldingsController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def model_class
              Spree::CouponHolding
            end

            def serializer_class
              Spree::Api::V3::Store::CouponHoldingSerializer
            end

            # The wallet is the customer's own, so every read is scoped to them
            # rather than to the store alone.
            def scope
              holdings = super.for_customer(current_user)

              case params[:status].presence
              when 'unused' then holdings.unused
              when 'used' then holdings.used
              when 'expired' then holdings.expired
              when 'expiring' then within(params[:expires_before], holdings)
              else holdings
              end
            end

            # The claim is the workflow: a code the customer already holds
            # enters the wallet, and the base class keeps the rendering.
            def create_workflow
              Spree::Coupons::Receive
            end

            def create_workflow_arguments
              { code: params[:code], customer: current_user, store: current_store,
                source: params[:source].presence }
            end

            # Both of these are read for every row, so they are loaded with the
            # page rather than per row.
            def collection_includes
              [{ coupon_code: :promotion }, :campaign]
            end

            def scope_includes
              collection_includes
            end

            # Newest first, and a client's own `sort` still leads: the base
            # applies it before this, so this is the tiebreaker rather than the
            # whole order.
            def apply_collection_sort(collection)
              collection.order(created_at: :desc, id: :desc)
            end

            private

            # What lapses before a date the customer named, read in the store's
            # own zone: a shopper who asks what runs out before the first of
            # next month means midnight where the store trades.
            #
            # @return [ActiveRecord::Relation]
            def within(date, holdings)
              return holdings if date.blank?

              day = Date.iso8601(date)
              zone = Time.find_zone(current_store.preferred_timezone) || Time.zone

              holdings.usable.where(spree_grants: { expires_at: ..zone.local(day.year, day.month, day.day) })
            end
          end
        end
      end
    end
  end
end
