module Spree
  module Api
    module V3
      # One coupon of an annual gift: which promotion it is — the id a claim
      # names when the member picks it — and whether they have taken it this
      # year.
      class YearGiftCouponSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize promotion_id: :string, name: :string, claimed: :boolean

        attribute(:promotion_id) { |coupon| coupon.promotion.prefixed_id }
        attribute(:name) { |coupon| coupon.promotion.name }
        attribute(:claimed) { |coupon| coupon.claimed? }
      end
    end
  end
end
