module Spree
  module Api
    module V3
      module Store
        # What a tier says a member saves, read before anybody buys it — the copy
        # the buy page's popup renders.
        #
        # Addressed by the package the page is showing, and resolved through this
        # store's own tiers: one another store sells is a 404 rather than
        # somebody else's copy.
        class MembershipSavingsController < Store::BaseController
          prepend_before_action :require_authentication!

          def index
            render json: Spree::Api::V3::MembershipSavingSerializer.new(tier, params: serializer_params).to_h
          end

          private

          # @return [Spree::MembershipTierSetting]
          def tier
            @tier ||= Spree::MembershipTierSetting.for_store(current_store).
                      find_by_prefix_id!(params[:tier_id])
          end
        end
      end
    end
  end
end
