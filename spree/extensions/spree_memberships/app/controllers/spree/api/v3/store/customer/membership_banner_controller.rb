module Spree
  module Api
    module V3
      module Store
        module Customer
          # The banner the member centre opens with: the picture of the tier the
          # customer is in, and the tap targets over it.
          #
          # A customer in no tier, or in a tier with no banner, is answered
          # `null` rather than refused — the page has nothing to show, which is
          # not an error — and the client reads a falsy answer as no banner.
          class MembershipBannerController < Store::BaseController
            prepend_before_action :require_authentication!

            def show
              banner = Spree::MembershipBanner.for_customer(current_user, store: current_store)

              render json: banner.nil? ? nil : Spree::Api::V3::MembershipBannerSerializer.new(
                banner, params: serializer_params
              ).to_h
            end
          end
        end
      end
    end
  end
end
