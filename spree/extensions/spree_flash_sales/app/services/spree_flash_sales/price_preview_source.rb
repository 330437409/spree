module SpreeFlashSales
  # What a seckill line costs: the activity's own price, for a request that
  # names the activity.
  #
  # It answers through the price preview's source seam rather than as a price
  # rule, because the price belongs to the activity and to nothing else. A
  # seckill refuses points and coupons *per activity*, so those verdicts travel
  # with the price — the settle page renders them rather than asking again, and
  # the amount it shows is the amount the discount will be written from.
  class PricePreviewSource
    # @param variant [Spree::Variant]
    # @param quantity [Integer]
    # @param customer [Object, nil] whose live ticket answers when the request
    #   names no activity — a cart being priced does not have to say which
    #   activity each of its lines came from, because the ticket it holds does
    # @param context [Hash] `flash_sale_id` names the activity; omitted, the
    #   customer's own holding tickets are asked
    # @return [Hash, nil] nil to decline, which leaves the catalogue to price it
    def self.call(variant:, quantity:, customer: nil, context: {})
      flash_sale = activity_for(context) || ticketed_activity_for(variant, customer)
      return nil if flash_sale.nil?

      item = flash_sale.items.find_by(variant: variant)
      return nil if item.nil?

      {
        amount: item.sale_amount.to_f,
        label: 'flash_sale',
        ends_at: ends_at_for(flash_sale),
        flags: {
          'flash_sale_id' => flash_sale.prefixed_id,
          'flash_sale_status' => flash_sale.window_status,
          'allows_points' => flash_sale.allows_points,
          'allows_coupons' => flash_sale.allows_coupons,
          'claimable' => claimable?(flash_sale, item, quantity)
        }
      }
    end

    # Writes the activity's price onto the cart's lines for the tickets this
    # customer is holding — the claim's own price, applied where the line already
    # exists. Called by the preview when the request brings a cart, because that
    # is the last moment before payment at which the server knows both.
    #
    # @param cart [Spree::Cart]
    # @param customer [Object, nil]
    # @return [void]
    def self.apply!(cart:, customer: nil)
      return if customer.nil?

      Spree::FlashSaleTicket.holding.where(customer: customer).find_each do |ticket|
        variants = ticket.flash_sale.items.select(:variant_id)
        cart.line_items.where(variant_id: variants).find_each do |line_item|
          Spree::FlashSales::ApplyTicketPrice.call(ticket: ticket, line_item: line_item)
        end
      end
    end

    # Only an activity whose window is open prices anything: a scheduled one has
    # not started, and an ended one is not offered anywhere.
    # @return [Spree::FlashSale, nil]
    def self.activity_for(context)
      id = context[:flash_sale_id] || context['flash_sale_id']
      return nil if id.blank?

      live(Spree::FlashSale.find_by_prefix_id(id))
    end
    private_class_method :activity_for

    # The activity behind a ticket this customer holds for this goods — the same
    # answer a named activity gives, found from what they are already holding.
    # @return [Spree::FlashSale, nil]
    def self.ticketed_activity_for(variant, customer)
      return nil if customer.nil?

      ticket = Spree::FlashSaleTicket.holding.where(customer: customer).order(:expires_at).detect do |candidate|
        candidate.flash_sale.items.exists?(variant: variant)
      end
      live(ticket&.flash_sale)
    end
    private_class_method :ticketed_activity_for

    # When the price it answers stops being offered: the close of the stretch the
    # activity is currently sold in, or the window's own end when it is sold
    # throughout. This is the instant the page's countdown renders.
    # @return [Time]
    def self.ends_at_for(flash_sale)
      flash_sale.current_slot&.ends_at || flash_sale.ends_at
    end
    private_class_method :ends_at_for

    def self.live(sale)
      return nil unless sale&.window_status == 'live'

      sale
    end
    private_class_method :live

    # Whether the activity still has units to sell — what the client renders
    # 活动库存不足 from, and the reason a page should not offer the seckill price
    # for an activity that has run out.
    def self.claimable?(flash_sale, item, quantity)
      flash_sale.progress(item: item).fetch(:remaining).to_i >= quantity.to_i
    end
    private_class_method :claimable?
  end
end
