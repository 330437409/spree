module Spree
  module Api
    module V3
      # The packet of coupons a tier grants, as both surfaces render it: the
      # coupons themselves, what the packet is worth in money, and whether it
      # holds one that is exchanged for goods.
      #
      # Deliberately not a `BaseSerializer`: a packet is a reading of a tier's
      # right rather than a record, so it has no id and nothing to update.
      class SurprisePacketSerializer
        include Alba::Resource
        include Typelizer::DSL
        include MembershipMoney

        typelize coupons: 'SurprisePacketCoupon[]', total_money_sum: :string,
                 exchange: :boolean, other_type: 'string | null'

        attribute(:coupons) do |packet|
          packet.coupons.map do |coupon|
            Spree::Api::V3::SurprisePacketCouponSerializer.new(coupon, params: params).to_h
          end
        end
        attribute(:total_money_sum) { |packet| decimal(packet.total_money_sum) }
        attribute(:exchange) { |packet| packet.exchange? }
        attribute(:other_type) { |packet| packet.other_type }
      end
    end
  end
end
