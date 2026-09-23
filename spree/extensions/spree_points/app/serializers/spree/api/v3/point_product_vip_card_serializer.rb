module Spree
  module Api
    module V3
      # The membership a `vip_card` good issues: the tier's own name.
      #
      # Deliberately not a `BaseSerializer`: that would publish the group's
      # id, which is an admin-side identifier and one the shop's read has no
      # use for.
      class PointProductVipCardSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize name: :string

        attributes :name
      end
    end
  end
end
