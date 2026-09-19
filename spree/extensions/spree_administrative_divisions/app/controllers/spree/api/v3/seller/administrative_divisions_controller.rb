module Spree
  module Api
    module V3
      module Seller
        # The tree as the seller panel's forms read it, for the same picker the
        # dashboard has: a seller binds their own warehouse's service area, so
        # they need the same list the operator reads.
        #
        # Read-only, and scoped as their stock is: naming a division is part of
        # administering their own warehouse and nothing else.
        class AdministrativeDivisionsController < Seller::BaseController
          include Spree::Api::V3::AdministrativeTree

          scoped_resource :stock
        end
      end
    end
  end
end
