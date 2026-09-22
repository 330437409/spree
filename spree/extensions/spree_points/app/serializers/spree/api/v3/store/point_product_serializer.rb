module Spree
  module Api
    module V3
      module Store
        # A good in the points shop: what it costs, whether it is on the shelf,
        # and what redeeming it issues.
        #
        # The issued thing is a nested serializer of its own rather than a hash
        # built here, and only the kind the row actually is fills its own
        # payload — the client reads the row and branches on `type`.
        class PointProductSerializer < BaseSerializer
          typelize type: :string, name: :string, image: 'string | null',
                   category: 'string | null', points: :number, money: :string,
                   stock: :number, in_stock: :boolean, featured: :boolean,
                   variant_id: 'string | null', vip_card: 'Record<string, unknown> | null'

          attributes :name, :image, :category, :points, :featured

          attribute(:type) { |product| product.class.api_type }

          attribute(:money) { |product| decimal_string(product.money) }
          attribute(:stock) { |product| product.stock }
          attribute(:in_stock) { |product| product.in_stock? }
          attribute(:variant_id) do |product|
            product.is_a?(Spree::PointProducts::Good) ? product.variant&.prefixed_id : nil
          end

          # A membership card good reads the tier's own name, which is the
          # group's: the card itself is issued by the membership plan when the
          # redemption completes.
          attribute(:vip_card) do |product|
            next unless product.is_a?(Spree::PointProducts::VipCard) && product.customer_group.present?

            Spree::Api::V3::Store::PointProductVipCardSerializer.new(
              product.customer_group, params: params
            ).to_h
          end
        end
      end
    end
  end
end
