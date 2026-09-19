module Spree
  module Api
    module V3
      module Admin
        # The tree as the dashboard's forms read it — the warehouse's service
        # area, and every other picker that names a division.
        #
        # Read-only: the tree is imported reference data, and a correction to it
        # is a new release rather than an edit (see the gem's README). A picker is
        # a stock-administration read, so it takes the same scope the stock
        # location screens do.
        class AdministrativeDivisionsController < Admin::BaseController
          include Spree::Api::V3::AdministrativeTree

          scoped_resource :stock
        end
      end
    end
  end
end
