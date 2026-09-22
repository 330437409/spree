module Spree
  module Coupons
    # Hands a coupon over: takes a code out of the promotion's pool, records the
    # grant the primitive owns, and writes the holding that says which code it
    # is.
    #
    # Idempotent by the key it is called with, so a draw somebody tapped twice,
    # or a settlement step a retry reached again, answers the holding the first
    # call wrote rather than handing over a second coupon.
    class Issue
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the holding
      def call(promotion:, source:, customer: nil, campaign: nil, store: nil,
               expires_at: nil, idempotency_key: nil, metadata: nil)
        store ||= Spree::Current.store
        return failure(nil, :key_missing) if idempotency_key.blank?

        attempts = 0

        begin
          record(promotion: promotion, source: source, customer: customer, campaign: campaign,
                 store: store, expires_at: expires_at, idempotency_key: idempotency_key,
                 metadata: metadata)
        rescue ActiveRecord::RecordNotUnique
          # Two callers chose the same free code at the same moment and the
          # unique index refused the second. The savepoint went with the failed
          # insert, so the whole issue runs once more — by then the other holder
          # is visible and the next code is the one chosen.
          attempts += 1
          retry if attempts < 2

          failure(nil, :coupon_just_taken)
        end
      end

      private

      # @return [Spree::ServiceModule::Result] value is the holding
      def record(promotion:, source:, customer:, campaign:, store:, expires_at:,
                 idempotency_key:, metadata:)
        result = nil

        Spree::CouponHolding.transaction(requires_new: true) do
          granted = Spree::Grants.grant!(
            kind: Spree::Coupons::Holding,
            customer: customer,
            source: campaign,
            idempotency_key: idempotency_key,
            expires_at: expires_at,
            store: store,
            metadata: metadata
          )

          # Whether the grant was just recorded or the key was already held,
          # the answer to a retry is the coupon the first call wrote: the
          # primitive answers a taken key with the row that holds it rather
          # than refusing.
          held = granted.value && Spree::CouponHolding.find_by(grant: granted.value)

          if held
            result = success(held)
            raise ActiveRecord::Rollback
          end

          if granted.failure?
            result = failure(nil, granted.error)
            raise ActiveRecord::Rollback
          end

          code = reserve_code(promotion)

          if code.nil?
            result = failure(nil, :coupon_none_left)
            raise ActiveRecord::Rollback
          end

          result = success(
            Spree::CouponHolding.create!(
              grant: granted.value,
              coupon_code: code,
              campaign: campaign,
              source: source
            )
          )
        end

        result
      end

      # A code of the promotion's pool that nobody holds yet, minted if the pool
      # has run dry. `Spree::CouponCodes::BulkGenerate` is core's own generator;
      # what this adds is the "and nobody holds it" half.
      #
      # `with_deleted` matches the unique index, which is not partial: a holding
      # somebody removed still holds its code.
      #
      # @return [Spree::CouponCode, nil]
      def reserve_code(promotion)
        held = Spree::CouponHolding.with_deleted.select(:coupon_code_id)

        2.times do
          code = promotion.coupon_codes.where.not(id: held).order(:id).first
          return code if code

          Spree::CouponCodes::BulkGenerate.call(promotion: promotion, quantity: 1)
        end

        nil
      end
    end
  end
end
