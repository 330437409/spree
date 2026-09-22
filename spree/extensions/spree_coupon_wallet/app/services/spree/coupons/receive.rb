module Spree
  module Coupons
    # Puts a code the customer already has into their wallet — the one the
    # platform texted them, or one the operator published.
    #
    # The code is the identity, so a second call with the same code answers the
    # same holding, and a code somebody else holds is refused rather than taken
    # from them.
    class Receive
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the holding
      def call(code:, customer:, store: nil, source: nil)
        source ||= 'sms'
        coupon_code = find_code(normalized(code), store)

        return failure(nil, :coupon_code_not_found) if coupon_code.nil?
        return claim(coupon_code, customer, source, store) if coupon_code.cart_id.nil? && coupon_code.order_id.nil?

        failure(nil, :coupon_code_in_use)
      end

      private

      # Codes are unique across the platform, so a lookup that is not scoped to
      # the store would let a shopper here claim a coupon that belongs to
      # another store's promotion — and the holding's own uniqueness would then
      # keep that store's campaign from ever handing the code to its customer.
      #
      # @return [Spree::CouponCode, nil]
      def find_code(code, store)
        return nil if store.nil?

        Spree::CouponCode.in_promotions(store.promotions.select(:id)).find_by(code: code)
      end

      # A code a promotion minted for wholesale use is the promotion's own and
      # not something a customer can hold, so a held code is only ever claimed
      # through its holding.
      def claim(coupon_code, customer, source, store)
        held = Spree::CouponHolding.with_deleted.find_by(coupon_code: coupon_code)

        if held
          # A coupon somebody removed is in nobody's wallet, and its code stays
          # reserved to it.
          return failure(nil, :coupon_already_held) if held.deleted_at.present?
          return failure(nil, :coupon_already_held) if held.customer_id.present? && held.customer_id != customer.id
          return success(held) if held.customer_id.present?

          claimed = Spree::Grants.claim!(held.grant, customer: customer)
          return failure(nil, claimed.error) if claimed.failure?

          return success(held.reload)
        end

        Spree::Coupons::Issue.call(
          promotion: coupon_code.promotion,
          customer: customer,
          source: source,
          store: store,
          idempotency_key: "coupon_code:#{coupon_code.id}",
          expires_at: nil
        )
      end

      def normalized(code)
        code.to_s.strip.downcase
      end
    end
  end
end
