module Spree
  module Api
    module V3
      module Store
        # Claiming a ticket — the client's 立即抢购, which is a claim rather than an
        # add to cart.
        #
        # A refusal is an answer, not a failure: the pool, the shelf and the
        # customer's own caps each say their own thing, and the reason travels
        # in `details` so the client can show the message its own dialog has for
        # that case instead of parsing prose.
        class FlashSaleTicketsController < ResourceController
          prepend_before_action :require_authentication!

          # POST /api/v3/store/flash_sale_tickets
          def create
            item = find_item
            return if performed?

            result = Spree::FlashSales::ClaimTicket.call(
              customer: current_user,
              item: item,
              quantity: params[:quantity],
              slot: find_slot(item),
              replacing: find_replaced_ticket
            )

            return render_claim(result.value) if result.success?

            render_refusal(result.value)
          end

          protected

          def serializer_class
            Spree::Api::V3::Store::FlashSaleTicketSerializer
          end

          def model_class
            Spree::FlashSaleTicket
          end

          private

          # The activity and the offer it sells, both read through the store's
          # own collections so an id from another tenant is a 404 and never a
          # foreign activity's pool.
          def find_item
            sale = Spree::FlashSale.for_store(current_store).find_by_prefix_id!(params[:flash_sale_id])
            variant = variant_scope.find_by_prefix_id!(params[:variant_id])
            item = sale.items.find_by(variant: variant)

            return item if item.present?

            render_error(
              code: ErrorHandler::ERROR_CODES[:validation_error],
              message: Spree.t('flash_sales.refusals.not_in_activity'),
              status: :unprocessable_content,
              details: { reason: 'not_in_activity' }
            )
            nil
          end

          # This store's variants, reached through its products: a gem cannot
          # add an association to `Spree::Store`, and an id from another tenant
          # has to be a 404 rather than a foreign shop's goods.
          def variant_scope
            Spree::Variant.where(product_id: current_store.products.select(:id))
          end

          def find_slot(item)
            return nil if params[:flash_sale_slot_id].blank?

            item.flash_sale.slots.find_by_prefix_id!(params[:flash_sale_slot_id])
          end

          # `oid` names the ticket being replaced, which is what a re-claim
          # sends; it is looked up among this customer's own.
          def find_replaced_ticket
            return nil if params[:replacing_ticket_id].blank?

            Spree::FlashSaleTicket.holding.where(store: current_store, customer: current_user).
              find_by_prefix_id!(params[:replacing_ticket_id])
          end

          def render_claim(ticket)
            render json: serialize_resource(ticket), status: :created
          end

          def render_refusal(reason)
            render_error(
              code: ErrorHandler::ERROR_CODES[:validation_error],
              message: Spree.t("flash_sales.refusals.#{reason}"),
              status: :unprocessable_content,
              details: { reason: reason.to_s }
            )
          end
        end
      end
    end
  end
end
