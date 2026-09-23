module Spree
  module Api
    module V3
      module Store
        module Customer
          module MembershipCards
            # 激活 — the wallet's own door to the activation transition.
            #
            # The gift's door claims a transfer first and ends at the same
            # transition, which is why there is one of these and not two.
            class ActivationsController < ResourceController
              prepend_before_action :require_authentication!
              before_action :set_card

              # POST /api/v3/store/customers/me/membership_cards/:membership_card_id/activations
              def create
                return render_card_transferring if Spree::Transfers.open?(@card.pending_transfer)

                result = Spree::MembershipCards::Activate.call(card: @card, customer: current_user)
                return render_result_error(result) if result.failure?

                render json: serialize_resource(result.value), status: :created
              end

              private

              # A card on its way to somebody may not be activated here, or the
              # window it is inside would strand: the recipient's claim would be
              # refused by the card already having a term. 作废 first, then this.
              #
              # A *live* window only — `Spree::Transfers.open?` is the one reader
              # of that rule. A window whose date has passed blocks nothing, and
              # the claim against it refuses on its own.
              #
              # The claim itself is the one door where a window and an activation
              # belong together, so the check sits at this door rather than in the
              # workflow both doors end at.
              def render_card_transferring
                render_error(
                  code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                  message: Spree.t('memberships.errors.card_transferring'),
                  status: :unprocessable_content
                )
              end

              protected

              def model_class
                Spree::MembershipCard
              end

              def serializer_class
                Spree::Api::V3::MembershipCardSerializer
              end

              # Through the customer's own cards, which is the whole
              # authorization: a card that is not theirs is not found.
              def set_card
                @card = Spree::MembershipCard.for_store(current_store).
                        for_customer(current_user).
                        find_by_prefix_id!(params[:membership_card_id])
              end
            end
          end
        end
      end
    end
  end
end
