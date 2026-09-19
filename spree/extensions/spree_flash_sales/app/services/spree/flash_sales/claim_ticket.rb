module Spree
  module FlashSales
    # Claiming a ticket: the shelf, the pool and the customer's own caps, decided
    # in one transaction.
    #
    # The order is the client's own — 商品库存不足, then 活动库存不足, then 已达活动限购数量
    # — and the answer it showed is the answer this makes, because both read the
    # same rules. **The pool is a cap and never a substitute for stock**: a claim
    # passes both, so an activity cannot sell what the shop has not got.
    #
    # A claim that replaces an earlier ticket releases it inside this same
    # transaction; without that, re-claiming would hold pool units for free.
    class ClaimTicket
      prepend Spree::ServiceModule::Base

      # The refusal reasons, and the order they are decided in.
      REFUSALS = %i[invalid_quantity slot_required not_started ended sold_out stock_short cap_reached
                   already_holding].freeze

      # @param customer [Object] the shopper claiming
      # @param item [Spree::FlashSale::Item] which offer, and so which activity
      # @param quantity [Integer]
      # @param slot [Spree::FlashSale::Slot, nil] the stretch claimed, defaulting
      #   to the one whose window is open
      # @param replacing [Spree::FlashSaleTicket, nil] the ticket this one
      #   replaces, which is what a re-claim passes
      # @param now [Time]
      # @return [Spree::ServiceModule::Result] the ticket, or the refusal
      def call(customer:, item:, quantity:, slot: nil, replacing: nil, now: Time.current)
        @customer = customer
        @item = item
        @flash_sale = item.flash_sale
        @quantity = quantity.to_i
        @now = now
        @replacing = replacing

        return failure(:invalid_quantity) if @quantity <= 0

        @slot = slot || @flash_sale.current_slot(now: @now)
        return failure(:slot_required) if @slot.nil? && @flash_sale.slots.exists?

        window = @flash_sale.window_status(now: @now)
        return failure(:not_started) if window == 'scheduled'
        return failure(:ended) if window == 'ended'

        result = nil
        Spree::FlashSale.transaction do
          @replacing&.release!(reason: 'replaced')
          result = claim
          raise ActiveRecord::Rollback if result.failure?
        end

        result
      end

      private

      def claim
        return failure(:cap_reached) if cap_reached?

        remaining = pools.map(&:remaining).min.to_i
        return failure(:sold_out) if remaining < @quantity
        return failure(:stock_short) unless Spree::Stock::Quantifier.new(@item.variant).can_supply?(@quantity)

        ticket = Spree::FlashSaleTicket.new(
          store: @flash_sale.store, flash_sale: @flash_sale, flash_sale_slot: @slot,
          variant: @item.variant, customer: @customer, quantity: @quantity,
          status: 'holding', expires_at: @now + Spree::FlashSaleTicket::DEFAULT_TTL
        )
        unless ticket.save
          return failure(:already_holding) if ticket.errors.of_kind?(:active_key, :taken)

          return failure(ticket.errors.full_messages.to_sentence)
        end

        # Every scope takes the same units, so a claim that runs out on the third
        # counter holds nothing on the first two.
        held = pools.all? do |pool|
          Spree::PoolHold.reserve!(owner: ticket, pool: pool, quantity: @quantity, expires_at: ticket.expires_at)
        end
        return failure(:sold_out) unless held

        success(ticket)
      end

      def pools
        @pools ||= [
          Spree::FlashSale::Pool.for!(flash_sale: @flash_sale, kind: 'all'),
          Spree::FlashSale::Pool.for!(flash_sale: @flash_sale, kind: 'day', on_date: @now.to_date),
          Spree::FlashSale::Pool.for!(flash_sale: @flash_sale, kind: 'slot', slot: @slot),
          Spree::FlashSale::Pool.for!(flash_sale: @flash_sale, kind: 'item', item: @item)
        ]
      end

      # The purchase caps are per customer, not per pool: how much this shopper
      # has already claimed, all time, today, and in this slot.
      def cap_reached?
        %i[all day slot].any? do |kind|
          limit = cap(kind)
          next false if limit.blank?

          claimed(kind) + @quantity > limit.to_i
        end
      end

      def cap(kind)
        case kind
        when :all then @flash_sale.purchase_cap_all
        when :day then @flash_sale.purchase_cap_day
        when :slot then @slot&.purchase_cap
        end
      end

      def claimed(kind)
        case kind
        when :all then claimed_scope.sum(:quantity)
        when :day then claimed_scope.where(created_at: @now.beginning_of_day..@now).sum(:quantity)
        when :slot then claimed_scope.where(flash_sale_slot: @slot).sum(:quantity)
        end
      end

      # What this customer already holds or bought: an expired, replaced or
      # cancelled ticket is not a purchase and does not count against a cap.
      def claimed_scope
        @claimed_scope ||= @flash_sale.tickets.where(customer: @customer, status: %w[holding settled])
      end
    end
  end
end
