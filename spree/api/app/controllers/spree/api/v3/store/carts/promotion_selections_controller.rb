module Spree
  module Api
    module V3
      module Store
        module Carts
          # Choosing between the promotions a line could be discounted by.
          #
          # The engine computes every candidate and applies one winner per line;
          # this is the shopper's answer to "which of these do you want",
          # written on the line and honoured by every recalculation after it
          # (docs/plans/6.1-store-api-miniprogram-gaps.md).
          #
          # Both identities the client sends come from the server's own list:
          # the promotion has to be a candidate for the line, and the code, when
          # sent, has to be that candidate's — a list that went stale between
          # rendering and choosing is refused rather than silently applied to
          # whichever promotion answers to the id today.
          class PromotionSelectionsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # POST /api/v3/store/carts/:cart_id/promotion_selection
            def create
              with_order_lock do
                promotion = chosen_promotion
                return if performed?

                line_item = target_line_item(promotion)
                return if performed?

                candidate = candidate_for(line_item, promotion)
                return if performed?

                verify_code!(candidate)
                return if performed?

                line_item.update!(chosen_promotion: promotion)

                result = Spree.cart_recalculate_workflow.call(cart: @cart)
                return render_result_error(result) if result.failure?

                render_cart
              end
            end

            private

            # The promotion the caller named, decoded from its own prefix so a
            # prefixed id belonging to something else is not one at all.
            #
            # @return [Spree::Promotion, nil] nil once the error has been rendered
            def chosen_promotion
              id = permitted_params[:promotion_id]
              if id.blank?
                return render_promotion_error('api.errors.promotion_selection_requires_promotion')
              end

              # Scoped by the candidate check below rather than by a store
              # query: a promotion this cart could not be discounted by is
              # not a candidate, whichever store it belongs to.
              promotion = Spree::Promotion.find_by(id: Spree::Promotion.decode_own_prefixed_id(id))
              return promotion if promotion

              render_promotion_error('api.errors.promotion_selection_not_a_candidate')
            end

            # The line the choice is about. A cart's picker is drawn per line, so
            # a caller may name it; when it does not, the promotion has to name
            # exactly one line of this cart — two would make the write mean
            # something it does not say.
            #
            # @param promotion [Spree::Promotion]
            # @return [Spree::LineItem, nil] nil once the error has been rendered
            def target_line_item(promotion)
              id = permitted_params[:line_item_id]

              if id.present?
                line_item = @cart.line_items.find_by(id: Spree::LineItem.decode_own_prefixed_id(id))
                return line_item if line_item

                return render_promotion_error('api.errors.cart_batch_unknown_line')
              end

              matching = @cart.line_items.select { |line_item| candidate_for(line_item, promotion, render: false) }
              return matching.first if matching.one?
              return render_promotion_error('api.errors.promotion_selection_not_a_candidate') if matching.empty?

              render_promotion_error('api.errors.promotion_selection_ambiguous')
            end

            # This line's candidate for that promotion.
            #
            # @return [Hash, nil] nil once the error has been rendered — or,
            #   with +render: false+, when the promotion simply does not apply
            #   to this line
            def candidate_for(line_item, promotion, render: true)
              candidate = line_item.promotion_candidates.detect do |entry|
                entry[:promotion].id == promotion.id
              end
              return candidate if candidate
              return nil unless render

              render_promotion_error('api.errors.promotion_selection_not_a_candidate_for_line')
            end

            # The code is the client's own copy of the list entry; when it no
            # longer matches the server's, the list the shopper chose from is
            # stale and the choice is refused rather than guessed at.
            def verify_code!(candidate)
              code = permitted_params[:promotion_code]
              return if code.blank? || code == candidate[:code]

              render_promotion_error('api.errors.promotion_selection_not_a_candidate_for_line')
            end

            def render_promotion_error(message_key)
              render_error(
                code: ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t(message_key),
                status: :unprocessable_content
              )
              nil
            end

            def permitted_params
              params.permit(:promotion_id, :promotion_code, :line_item_id)
            end
          end
        end
      end
    end
  end
end
