module Spree
  module Api
    module V3
      module Store
        module Customer
          # The member day: the weekday the customer's tier buys on better terms,
          # whether today is it, and what the day gives.
          #
          # One read for the member-day page and the home page's popup, because
          # they are one block — the popup is this plus the `today` the page has no
          # use for. A customer in no tier, or in one whose day nobody scheduled, is
          # answered `null` the way a tier with no banner is: nothing to show is not
          # an error.
          class MembershipDayController < Store::BaseController
            prepend_before_action :require_authentication!

            def show
              day = Spree::MembershipRights::SvipDate.for_customer(current_user, store: current_store)

              render json: day.nil? ? nil : Spree::Api::V3::MemberDaySerializer.new(
                day, params: serializer_params
              ).to_h
            end
          end
        end
      end
    end
  end
end
