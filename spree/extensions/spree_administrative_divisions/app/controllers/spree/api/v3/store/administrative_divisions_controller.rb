module Spree
  module Api
    module V3
      module Store
        # The tree as a customer's own forms read it — the address picker and the
        # seller-join form, both of which ask before anyone has signed in.
        #
        # The reading itself is shared with the dashboard's and the seller
        # panel's copies of the same picker; see AdministrativeTree.
        class AdministrativeDivisionsController < Store::BaseController
          include Spree::Api::V3::AdministrativeTree

          allow_guest_storefront_access!
        end
      end
    end
  end
end
