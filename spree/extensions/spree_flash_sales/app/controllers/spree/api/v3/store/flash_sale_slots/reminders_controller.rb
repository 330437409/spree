module Spree
  module Api
    module V3
      module Store
        module FlashSaleSlots
          # 开售提醒: remembering who is waiting for a stretch to open.
          #
          # Storing the wait is this gem's; sending the message is the message
          # relay's (`6.1-notifications.md`), which is why nothing here sends
          # anything.
          class RemindersController < Store::BaseController
            prepend_before_action :require_authentication!

            # POST /api/v3/store/flash_sale_slots/:flash_sale_slot_id/reminder
            def create
              reminder = Spree::FlashSale::Reminder.find_or_create_by!(
                store: current_store, flash_sale: slot.flash_sale, flash_sale_slot: slot, customer: current_user
              )

              render json: serialize(reminder), status: :created
            end

            # DELETE /api/v3/store/flash_sale_slots/:flash_sale_slot_id/reminder
            def destroy
              existing = Spree::FlashSale::Reminder.find_by(
                store: current_store, flash_sale_slot: slot, customer: current_user
              )
              existing&.destroy!

              head :no_content
            end

            private

            # Scoped to this store's activities, so a slot id from another
            # tenant is a 404.
            def slot
              @slot ||= Spree::FlashSale::Slot.joins(:flash_sale).
                        merge(Spree::FlashSale.for_store(current_store)).
                        find_by_prefix_id!(params[:flash_sale_slot_id])
            end

            def serialize(reminder)
              { flash_sale_slot_id: reminder.flash_sale_slot.prefixed_id, waiting: true }
            end
          end
        end
      end
    end
  end
end
