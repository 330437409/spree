module Spree
  module Api
    module V3
      module Store
        # The promotion behind a held coupon: its name, which is what the
        # wallet's row shows.
        #
        # Deliberately not a `BaseSerializer`: that would publish the
        # promotion's id and its timestamps, which a customer's wallet has no
        # use for.
        class CouponPromotionSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize name: :string

          attributes :name
        end
      end
    end
  end
end
