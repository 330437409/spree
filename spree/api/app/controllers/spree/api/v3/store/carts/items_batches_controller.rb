module Spree
  module Api
    module V3
      module Store
        module Carts
          # A set of lines written in one pass.
          #
          # The single-item endpoints write one line per request, but a combo
          # added whole, an order re-added, or a group's quantities changed
          # together are one gesture to the shopper and belong in one write.
          # The quantities are the set the cart should end up holding — a
          # retried batch writes the same cart rather than adding twice — and
          # the whole set recalculates once.
          #
          # A batch is not all-or-nothing: an entry the cart's own rules refuse
          # (out of stock, an unsellable currency) is reported on the cart's
          # warnings and the rest of the set still applies, which is what a
          # client restoring saved goods needs. A request that cannot be
          # applied at all — an empty set, a quantity that is not a positive
          # whole number, a line this cart does not hold — is refused whole,
          # because none of those is a fact about one entry
          # (docs/plans/6.1-store-api-miniprogram-gaps.md).
          class ItemsBatchesController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # POST /api/v3/store/carts/:cart_id/items/batch
            def create
              with_order_lock do
                items = batch_items
                return if performed?

                result = Spree.cart_upsert_items_workflow.call(cart: @cart, items: items)

                if result.success?
                  render_cart(status: :created)
                else
                  render_result_error(result)
                end
              end
            end

            private

            # The set as the workflow reads it: one entry per line to write,
            # each addressed by a variant — or by a line of this cart, whose
            # variant is what the write merges on.
            #
            # @return [Array<Hash>, nil] nil once an error has been rendered
            def batch_items
              entries = Array(permitted_params[:items])
              return render_batch_problem(:cart_batch_requires_items) if entries.empty?

              entries.map { |entry| batch_item(entry.to_h.symbolize_keys) }
            end

            def batch_item(entry)
              quantity = quantity_param(entry[:quantity])
              return nil if performed?

              line_item = line_item_param(entry[:line_item_id])
              return nil if performed?

              variant_id = line_item ? line_item.variant_id : entry[:variant_id].presence
              return render_batch_problem(:cart_batch_requires_item) if variant_id.nil?

              { variant_id: variant_id, quantity: quantity, metadata: entry[:metadata] }
            end

            # A line the cart does not hold is the client's own state being
            # stale: answering with a different set than the one it asked for
            # would hide that, and writing everything else under it would
            # report a cart the shopper did not ask for.
            #
            # @return [Spree::LineItem, nil]
            def line_item_param(line_item_id)
              return nil if line_item_id.blank?

              line_item = @cart.line_items.find_by(id: Spree::LineItem.decode_own_prefixed_id(line_item_id))
              return line_item if line_item

              render_batch_problem(:cart_batch_unknown_line)
            end

            # The write sets a quantity, so an entry that names one must name a
            # real one: removals are the DELETE endpoint's, and a zero would
            # otherwise delete a line through a write that reads as an edit.
            #
            # @return [Integer, nil] nil once an error has been rendered
            def quantity_param(value)
              return 1 if value.blank?

              quantity = Integer(value, exception: false)
              return quantity if quantity&.positive?

              render_error(
                code: ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('cart_line_item.quantity_must_be_positive'),
                status: :unprocessable_content
              )
              nil
            end

            def render_batch_problem(key)
              render_error(
                code: ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t("api.errors.#{key}"),
                status: :unprocessable_content
              )
              nil
            end

            def permitted_params
              params.permit(items: [:variant_id, :line_item_id, :quantity, { metadata: {} }])
            end
          end
        end
      end
    end
  end
end
