module Spree
  module Api
    module V3
      module Store
        # The membership a `vip_card` good issues: the tier's own name, which
        # is the customer group's, and nothing the group does not carry.
        class PointProductVipCardSerializer < BaseSerializer
          typelize name: :string

          attributes :name
        end
      end
    end
  end
end
