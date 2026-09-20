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
          # selection when the cart is completed
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

                @cart.line_items.where(id: lines).update_all(selected: selected_param)

                render_cart
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

            # @return [Boolean]
            def selected_param
              ActiveModel::Type::Boolean.new.cast(permitted_params[:selected])
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
