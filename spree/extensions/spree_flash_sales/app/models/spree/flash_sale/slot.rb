module Spree
  class FlashSale
    # A stretch of an activity — the client's timeDetailId — with its own pool
    # and purchase cap, and the thing a 开售提醒 is keyed to.
    class Slot < Spree.base_class
      has_prefix_id :fslot

      belongs_to :flash_sale, class_name: 'Spree::FlashSale', inverse_of: :slots
      has_many :pools, class_name: 'Spree::FlashSale::Pool', dependent: :destroy, inverse_of: :slot
      has_many :tickets, class_name: 'Spree::FlashSaleTicket', dependent: :nullify,
                         inverse_of: :flash_sale_slot
      has_many :reminders, class_name: 'Spree::FlashSale::Reminder', dependent: :destroy, inverse_of: :flash_sale_slot

      validates :starts_at, :ends_at, presence: true
      validate :ends_after_it_starts

      scope :ordered, -> { order(:position, :starts_at) }

      # @return [String] scheduled, live or ended, from the server's clock
      def window_status(now: Time.current)
        return 'ended' if ends_at <= now
        return 'live' if starts_at <= now

        'scheduled'
      end

      private

      def ends_after_it_starts
        return if starts_at.blank? || ends_at.blank?
        return if ends_at > starts_at

        errors.add(:ends_at, :must_be_after_starts_at)
      end
    end
  end
end
