module Spree
  module Api
    module V3
      # An activity as a storefront reads it.
      #
      # `server_now` travels with every answer because the client's countdown
      # ticks against the server's instant, never against the device clock: a
      # phone whose clock is a minute fast would otherwise end the activity
      # early or start it late. `window_status` is derived from that same
      # instant, so an activity the client may not buy from yet says so.
      class FlashSaleSerializer < BaseSerializer
        typelize window_status: :string,
                 title: [:string, nullable: true], code: [:string, nullable: true],
                 starts_at: [:string, nullable: true], ends_at: [:string, nullable: true],
                 server_now: :string, items: 'FlashSaleItem[]', slots: 'FlashSaleSlot[]',
                 remaining: :number, percentage: :number, standby_tickets: :number

        attributes :title, :code

        attribute :window_status do |flash_sale|
          flash_sale.window_status(now: now)
        end

        attributes :starts_at, :ends_at

        attribute :server_now do
          now.iso8601
        end

        attribute :remaining do |flash_sale|
          progress_for(flash_sale).fetch(:remaining)
        end

        attribute :percentage do |flash_sale|
          progress_for(flash_sale).fetch(:percentage)
        end

        # How many unpaid tickets are ahead of whoever is reading — the client
        # renders 前面还有 {{standbyTicket}} 人未支付.
        attribute :standby_tickets do |flash_sale|
          queue_for(flash_sale).count
        end

        attribute :items do |flash_sale|
          flash_sale.items.ordered.map { |item| FlashSaleItemSerializer.new(item, params: params).to_h }
        end

        attribute :slots do |flash_sale|
          flash_sale.slots.ordered.map { |slot| FlashSaleSlotSerializer.new(slot, params: params).to_h }
        end

        private

        def now
          @now ||= Time.current
        end

        def open_slot_for(flash_sale)
          flash_sale.current_slot(now: now)
        end

        def progress_for(flash_sale)
          @progress ||= {}
          @progress[flash_sale.id] ||= flash_sale.progress(now: now)
        end

        def queue_for(flash_sale)
          @queue ||= {}
          @queue[flash_sale.id] ||= Spree::FlashSaleTicket.holding.where(flash_sale: flash_sale).
                                    where(flash_sale_slot: open_slot_for(flash_sale))
        end
      end
    end
  end
end
