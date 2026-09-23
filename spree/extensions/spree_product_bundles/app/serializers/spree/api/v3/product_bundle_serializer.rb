module Spree
  module Api
    module V3
      # A bundle as a storefront reads it: the components, what they cost one
      # by one, what the set costs, what it saves, and how many sets the shelf
      # can fill.
      #
      # All three figures are the server's — a client derives none of them —
      # and the availability is a number rather than a verdict, because the
      # client compares it against a threshold of its own before it says
      # 套餐商品不足.
      class ProductBundleSerializer < BaseSerializer
        typelize title: :string, slug: :string,
                 goods_price: :number, price: :number, saving: :number,
                 available: :number,
                 seller_id: [:string, nullable: true]

        attributes :title, :slug

        attribute :goods_price do |bundle|
          bundle.goods_price(currency).to_f
        end

        attribute :price do |bundle|
          bundle.price.to_f
        end

        attribute :saving do |bundle|
          bundle.saving.to_f
        end

        # In bundles, not in units: `min(component available / quantity)`.
        attribute :available do |bundle|
          bundle.available_bundles
        end

        attribute :seller_id do |bundle|
          bundle.seller&.prefixed_id
        end

        many :components,
             resource: proc { Spree::Api::V3::BundleComponentSerializer }

        private

        def currency
          params[:currency] || Spree::Current.currency
        end
      end
    end
  end
end
