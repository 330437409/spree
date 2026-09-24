module Spree
  module Api
    module V3
      module Admin
        # The banner as the operator edits it: the storefront's own fields, plus
        # the record's timestamps. The typelize declarations are restated because
        # an admin serializer does not inherit its store parent's.
        class MembershipBannerSerializer < Spree::Api::V3::MembershipBannerSerializer
          # `areas` is left loose here on purpose: the area serializer is
          # store-side, so its type is generated into the store SDK alone and
          # naming it would break the admin build.
          typelize name: 'string | null', pic: :string, areas: 'Array<Record<string, unknown>>',
                   deleted_at: 'string | null'

          attributes :created_at, :updated_at, :deleted_at
        end
      end
    end
  end
end
