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
    # @param customer [Object, nil] unused today: a seckill prices the same for
    #   everyone the activity can serve, and the caps are enforced at the claim
    # @param context [Hash] `flash_sale_id` names the activity
    # @return [Hash, nil] nil to decline, which leaves the catalogue to price it
    def self.call(variant:, quantity:, customer: nil, context: {})
      flash_sale = activity_for(context)
      return nil if flash_sale.nil?

      item = flash_sale.items.find_by(variant: variant)
      return nil if item.nil?

      {
        amount: item.sale_amount.to_f,
        label: 'flash_sale',
        flags: {
          'flash_sale_id' => flash_sale.prefixed_id,
          'flash_sale_status' => flash_sale.window_status,
          'allows_points' => flash_sale.allows_points,
          'allows_coupons' => flash_sale.allows_coupons,
          'claimable' => claimable?(flash_sale, item, quantity)
        }
      }
    end

    # Only an activity whose window is open prices anything: a scheduled one has
    # not started, and an ended one is not offered anywhere.
    # @return [Spree::FlashSale, nil]
    def self.activity_for(context)
      id = context[:flash_sale_id] || context['flash_sale_id']
      return nil if id.blank?

      sale = Spree::FlashSale.find_by_prefix_id(id)
      return nil unless sale&.window_status == 'live'

      sale
    end
    private_class_method :activity_for

    # Whether the activity still has units to sell — what the client renders
    # 活动库存不足 from, and the reason a page should not offer the seckill price
    # for an activity that has run out.
    def self.claimable?(flash_sale, item, quantity)
      flash_sale.progress(item: item).fetch(:remaining).to_i >= quantity.to_i
    end
    private_class_method :claimable?
  end
end
