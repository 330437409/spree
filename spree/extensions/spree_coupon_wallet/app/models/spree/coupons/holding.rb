module Spree
  module Coupons
    # The kind of grant a coupon the customer holds is.
    #
    # The primitive records that the store owes a coupon and the wallet's side
    # table records which one. Neither spends it: a coupon is spent when the
    # promotion system applies its code to an order, through
    # `carts/:cart_id/discount_codes`, which is the one application path this
    # repository has.
    class Holding < Spree::Grants::Kind
      def self.api_type
        'coupon_holding'
      end

      # A coupon reaches a wallet one code at a time, and the code is what
      # makes two grants one: a producer that knows why it is handing one over
      # passes its own key, and a retry answers the holding the first call
      # wrote rather than a second coupon.
      #
      # @raise [NotImplementedError]
      def self.idempotency_key_for(_context)
        raise NotImplementedError, 'a coupon holding is granted with an explicit idempotency_key'
      end

      # @return [Boolean]
      def self.consumable?
        false
      end

      # @return [Spree::ServiceModule::Result]
      def self.consume!(grant)
        refuse(grant, :applied_at_checkout)
      end
    end
  end
end
