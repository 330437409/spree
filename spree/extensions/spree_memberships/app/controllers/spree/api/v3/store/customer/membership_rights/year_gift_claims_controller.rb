module Spree
  module Api
    module V3
      module Store
        module Customer
          module MembershipRights
            # 立即领取 — the annual gift's claim.
            #
            # A claim is the member's and the right is the tier's, so this is a
            # resource of its own under the right rather than an edit to it: the
            # right is the same for everybody on the tier, and what a claim
            # changes is one member's own state of it.
            class YearGiftClaimsController < ResourceController
              prepend_before_action :require_authentication!
              # A custom action whose parent rides in the path rather than in
              # `params[:id]`, so the base's loader never runs.
              skip_before_action :set_resource, raise: false
              before_action :set_right

              # POST /api/v3/store/customers/me/membership_rights/:membership_right_id/year_gift_claims
              def create
                result = Spree::Memberships::ClaimYearGift.call(
                  right: @right,
                  customer: current_user,
                  promotion_id: params[:promotion_id],
                  store: current_store
                )
                return render_result_error(result) if result.failure?

                render json: serialize_resource(result.value), status: :created
              end

              protected

              def model_class
                Spree::MembershipRight
              end

              # What a claim answers with is the coupon it handed over, as the
              # wallet renders it: what the member goes on to show or type at
              # checkout.
              def serializer_class
                Spree::Api::V3::CouponHoldingSerializer
              end

              private

              # Through the store's own ladder, so a right of another store is
              # not found rather than claimed.
              def set_right
                @right = Spree::MembershipRight.for_store(current_store).
                         find_by_prefix_id!(params[:membership_right_id])
              end
            end
          end
        end
      end
    end
  end
end
