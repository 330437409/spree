module Spree
  module Api
    module V3
      # One member's annual gift, as the member centre lists it: how it is
      # claimed, what is left of the year's allowance, how much of the gift is
      # still unclaimed, and the coupons themselves with the ones this member has
      # already taken marked.
      #
      # Deliberately not a `BaseSerializer`: a gift is not a record, so it has no
      # id and no timestamps to publish.
      class YearGiftSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize mode: :string, can_count: :number, usable_num: :number,
                 coupons: 'Array<Record<string, unknown>>'

        attribute(:mode) { |gift| gift.mode }
        attribute(:can_count) { |gift| gift.can_count }
        attribute(:usable_num) { |gift| gift.usable_num }

        attribute(:coupons) do |gift|
          gift.coupons.map { |coupon| Spree::Api::V3::YearGiftCouponSerializer.new(coupon).to_h }
        end
      end
    end
  end
end
