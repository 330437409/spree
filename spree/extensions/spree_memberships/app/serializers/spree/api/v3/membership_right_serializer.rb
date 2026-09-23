module Spree
  module Api
    module V3
      # One right a tier carries, as the rights catalogue lists it.
      #
      # The kind is the wire shorthand and the display name is the row's own
      # copy: the client renders what it is given and maps nothing, which is
      # what lets an operator add or rename a kind without a release.
      class MembershipRightSerializer < BaseSerializer
        typelize type: :string, name: :string, description: 'string | null',
                 badge: 'string | null', image_url: 'string | null',
                 published: :boolean, tier: 'Record<string, unknown> | null'

        attribute(:type) { |right| Spree::MembershipRight.api_type_for(right.type) }
        attribute(:name) { |right| right.display_name }
        attributes :description, :badge, :image_url
        attribute(:published) { |right| right.published? }
        attribute(:tier) do |right|
          next if right.tier_setting.nil?

          Spree::Api::V3::MembershipTierSerializer.new(right.tier_setting, params: params).to_h
        end
      end
  end
end
end
