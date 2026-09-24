module Spree
  module Api
    module V3
      module Store
        # What a customer is walking into before they buy a term: the warning the
        # client shows instead of taking their money first.
        #
        # The tier is named by the id the buy page already renders, and the id is
        # resolved through this store's own tiers — one another store sells is a
        # 404 rather than a question answered about somebody else's catalogue.
        class MembershipPurchaseChecksController < Store::BaseController
          prepend_before_action :require_authentication!

          # An empty list is the ordinary answer, not a missing one: the client
          # reads "nothing to warn about" and buys.
          def index
            render json: { checks: serialized_checks }
          end

          private

          # @return [Spree::MembershipTierSetting]
          def tier
            @tier ||= Spree::MembershipTierSetting.for_store(current_store).
                      find_by_prefix_id!(params[:tier_id])
          end

          def serialized_checks
            checks = Spree::MembershipKinds::Vip.purchase_checks(tier: tier, customer: current_user)

            checks.map do |check|
              Spree::Api::V3::MembershipPurchaseCheckSerializer.new(check, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end
