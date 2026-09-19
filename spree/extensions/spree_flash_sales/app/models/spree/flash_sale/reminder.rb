module Spree
  class FlashSale
    # A customer waiting for a slot to open (开售提醒). Storing the wait is this
    # gem's; delivering the message is `6.1-notifications.md`'s, which is why
    # nothing here sends anything.
    class Reminder < Spree.base_class
      belongs_to :store, class_name: 'Spree::Store'
      belongs_to :flash_sale, class_name: 'Spree::FlashSale', inverse_of: :reminders
      belongs_to :flash_sale_slot, class_name: 'Spree::FlashSale::Slot', inverse_of: :reminders
      belongs_to :customer, class_name: "::#{Spree.customer_class}"

      validates :customer_id, uniqueness: { scope: [:flash_sale_slot_id, *spree_base_uniqueness_scope] }
    end
  end
end
