module Spree
  module Api
    module V3
      module Store
        module Customer
          # Whether today is this customer's member day — asked when they tap buy on
          # a day-page card, before it reaches a cart.
          #
          # A **check rather than a read**: the client reads a refusal as "you are
          # not in the member day; carry on without the multiplier?" and lets the
          # customer continue, so what it needs is a verdict and a sentence, not a
          # payload. Eligible answers `204`; anything else refuses with the reason,
          # which is the multiplier rather than the red packet — the client's own
          # copy says 多倍积分, and the packet is not what tapping buy asks about.
          class MembershipDayCheckController < Store::BaseController
            prepend_before_action :require_authentication!

            def show
              day = Spree::MembershipRights::SvipDate.for_customer(current_user, store: current_store)

              return head :no_content if day&.today?

              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('memberships.errors.not_member_day'),
                status: :unprocessable_content
              )
            end
          end
        end
      end
    end
  end
end
