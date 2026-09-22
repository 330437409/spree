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

        result = nil

        Spree::CouponHolding.transaction(requires_new: true) do
          granted = Spree::Grants.grant!(
            kind: Spree::Coupons::Holding,
            customer: customer,
            source: campaign || granted_by(source),
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

      private

      # What caused the grant when no campaign did: the source is the wallet's
      # own vocabulary and the primitive wants the record behind it, so a
      # purchase points at its order and an operator's hand at nothing.
      #
      # @return [Object, nil]
      def granted_by(source)
        source if source.respond_to?(:id)
      end

      # A code of the promotion's pool that nobody holds yet, minted if the pool
      # has run dry. `Spree::CouponCodes::BulkGenerate` is core's own generator;
      # what this adds is the "and nobody holds it" half.
      #
      # The second pass is for the one race a check-then-insert cannot close:
      # two draws choosing the same free code at the same moment, where the
      # unique index refuses the second and the code it wants is gone by then.
      # `with_deleted` matches that index, which is not partial: a holding
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
      rescue ActiveRecord::RecordNotUnique
        # The code was taken between choosing it and writing the holding, and
        # `create!` raised out of the transaction. The savepoint is gone with
        # it, so this answers the refusal rather than retrying inside a
        # transaction PostgreSQL has already aborted.
        nil
      end
    end
  end
end
