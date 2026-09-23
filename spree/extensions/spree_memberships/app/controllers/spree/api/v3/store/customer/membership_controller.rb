module Spree
  module Api
    module V3
      module Store
        module Customer
          # The customer's own membership: which rung they are on, what it
          # carries, and the panels its rights fall into.
          #
          # A customer in no tier is not an error — it is a customer with no
          # membership, and the read says so with a null tier and no sections.
          class MembershipController < Store::BaseController
            prepend_before_action :require_authentication!

            def show
              centre = Spree::Memberships::MemberCentre.new(store: current_store, customer: current_user)

              render json: Spree::Api::V3::MemberCentreSerializer.new(
                centre, params: serializer_params
              ).to_h
            end

          end
        end
      end
    end
  end
end
