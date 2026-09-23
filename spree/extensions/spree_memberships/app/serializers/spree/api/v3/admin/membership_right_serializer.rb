module Spree
  module Api
    module V3
      module Admin
        # One right as the operator edits it: the kind, the row's own copy, and
        # the settings that kind declares.
        class MembershipRightSerializer < BaseSerializer
          typelize type: :string, position: :number, published: :boolean,
                   name: :string, description: 'string | null', badge: 'string | null',
                   image_url: 'string | null', deleted_at: 'string | null',
                   preferences: 'Record<string, unknown> | null'

          attribute(:type) { |right| Spree::MembershipRight.api_type_for(right.type) }
          attributes :name, :description, :badge, :image_url, :position
          attribute(:published) { |right| right.published? }
          attribute(:preferences) { |right| right.serialized_preferences }
          attributes :created_at, :updated_at, :deleted_at
        end
      end
    end
  end
end
