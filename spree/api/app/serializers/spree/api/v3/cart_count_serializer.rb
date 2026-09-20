module Spree
  module Api
    module V3
      # A cart's item counts, for the badge a storefront renders on every page.
      #
      # The two figures are the cart serializer's own — one vocabulary, so a
      # client that reads `total_quantity` off the cart reads it here too — and
      # the payload carries nothing else. That is the point: the badge is asked
      # for on pages that have no reason to pull a cart full of lines, variants,
      # media and prices (docs/plans/6.1-store-api-miniprogram-gaps.md).
      class CartCountSerializer < BaseSerializer
        typelize total_quantity: :number, selected_quantity: :number

        attributes :total_quantity, :selected_quantity
      end
    end
  end
end
