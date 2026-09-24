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

        private

        # Plain decimal notation, which is the wire form every money field of
        # this API uses: `BigDecimal#to_s` on its own renders 0.06 as "0.6e-1".
        def decimal(value)
          BigDecimal(value.to_s).to_s('F')
        end
      end
    end
  end
end
