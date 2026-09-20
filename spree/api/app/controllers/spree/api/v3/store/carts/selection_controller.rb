module Spree
  module Api
    module V3
      module Store
        module Carts
          # Which of a cart's lines take part in checkout.
          #
          # A shopper ticks lines as they shop, and the ticks are durable cart
          # state rather than a flag applied at checkout: no request in the
          # checkout path names them, so the server reads the cart's own
          # selection when it prices the cart and when it is completed
          # (docs/plans/6.1-store-api-miniprogram-gaps.md).
          #
          # It is written in bulk — one tick, or a whole group's — because that
          # is how the client writes it, and a per-line request per tick would
          # be a round trip per gesture.
          class SelectionController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # PATCH /api/v3/store/carts/:cart_id/selection
            def update
              with_order_lock do
                lines = lines_param
                return if performed?

                selected = selected_param
                return if performed?

                result = Spree.cart_select_lines_workflow.call(
                  cart: @cart,
                  line_items: @cart.line_items.where(id: lines),
                  selected: selected
                )

                if result.success?
                  render_cart
                else
                  render_result_error(result)
                end
              end
            end

            private

            # The lines the caller means. An id this cart does not hold is
            # simply not one of them: the selection is written over the cart's
            # own lines and nothing else.
            #
            # @return [Array<Integer>]
            def lines_param
              # Form-encoded empty collections arrive as `[""]`, which is an
              # absence rather than a line.
              ids = Array(permitted_params[:line_item_ids]).reject(&:blank?)

              if ids.empty?
                render_error(
                  code: ErrorHandler::ERROR_CODES[:validation_error],
                  message: Spree.t('api.errors.cart_selection_requires_lines'),
                  status: :unprocessable_content
                )
                return []
              end

              ids.filter_map { |id| Spree::LineItem.decode_own_prefixed_id(id) }
            end

            # The way to go. An absent or unrecognised value is not "false" —
            # the cast answers nil — and writing nil into a column that forbids
            # it would surface a client's mistake as a server fault, so it is
            # refused here with the same answer an empty line set gets.
            #
            # @return [Boolean, nil] nil once the error has been rendered
            def selected_param
              selected = ActiveModel::Type::Boolean.new.cast(permitted_params[:selected])
              return selected unless selected.nil?

              render_error(
                code: ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('api.errors.cart_selection_requires_state'),
                status: :unprocessable_content
              )
              nil
            end

            def permitted_params
              params.permit(:selected, line_item_ids: [])
            end
          end
        end
      end
    end
  end
end
