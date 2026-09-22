module Spree
  module Api
    module V3
      module Store
        module Customer
          # The customer's own wallet: the coupons they hold, one of them, and
          # the way a code they already have enters it.
          #
          # `create` is not a row the client fills in — it is a code the
          # platform texted them or the operator published, claimed into the
          # wallet, so the service runs and its result is the answer.
          class CouponHoldingsController < ResourceController
            prepend_before_action :require_authentication!

            # The wallet's create is not a record the client fills in — it is a
            # code the customer already has, claimed into the wallet — so the
            # service runs and its result is the answer. Public, because Rails
            # dispatches to public methods only: a protected one is not an
            # action at all.
            def create
              result = Spree::Coupons::Receive.call(
                code: params[:code],
                customer: current_user,
                store: current_store,
                source: params[:source].presence || 'sms'
              )

              return render_result_error(result) unless result.success?

              render json: serialize_resource(result.value), status: :created
            end

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

            # Newest first: a wallet is read from what just arrived.
            def apply_collection_sort(collection)
              collection.reorder(created_at: :desc, id: :desc)
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
