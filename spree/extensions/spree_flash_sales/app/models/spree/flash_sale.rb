module Spree
  # A timed activity: a window, a pool in three scopes, and the items it sells.
  #
  # The window is answered from the server clock rather than from the client's,
  # and an ended activity is absent from the reads rather than rendered in a
  # third state — which is why `window_status` exists beside the stored `status`
  # the operator's own lifecycle records.
  class FlashSale < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata

    acts_as_paranoid
    publishes_lifecycle_events

    has_prefix_id :fsale

    # The client's two card types: a seckill has its own page and buy popup, a
    # discount rides the ordinary product page with a badge. One activity with
    # two presentations.
    CODES = %w[seckill discount].freeze

    include Spree::HasStatus

    # The stored status is the operator's own lifecycle, moved by a workflow.
    # What a storefront may buy from is the *window*, answered from the server's
    # clock — see #window_status, which is what the reads render.
    has_status :scheduled, :live, :ended, default: :scheduled

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :seller, class_name: 'Spree::Seller', optional: true
    has_many :slots, class_name: 'Spree::FlashSale::Slot', dependent: :destroy, inverse_of: :flash_sale
    has_many :items, class_name: 'Spree::FlashSale::Item', dependent: :destroy, inverse_of: :flash_sale
    has_many :pools, class_name: 'Spree::FlashSale::Pool', dependent: :destroy, inverse_of: :flash_sale
    has_many :tickets, class_name: 'Spree::FlashSaleTicket', dependent: :destroy, inverse_of: :flash_sale
    has_many :reminders, class_name: 'Spree::FlashSale::Reminder', dependent: :destroy, inverse_of: :flash_sale

    normalizes :code, with: ->(value) { value.to_s.strip.presence }

    validates :title, :code, :starts_at, :ends_at, presence: true
    validates :code, inclusion: { in: CODES }
    validate :ends_after_it_starts

    # What the window says, from the server's clock. `ended` is not a state the
    # reads render: an activity whose window has closed is simply not offered.
    # @param now [Time]
    # @return [String] scheduled, live or ended
    def window_status(now: Time.current)
      return 'ended' if ends_at <= now
      return 'live' if starts_at <= now

      'scheduled'
    end

    # The slot whose window is open, which is the one a claim belongs to when
    # the client names none.
    # @return [Spree::FlashSale::Slot, nil]
    def current_slot(now: Time.current)
      slots.select { |slot| slot.starts_at <= now && slot.ends_at > now }.min_by(&:position)
    end

    # The figures the client renders — 已抢光 and its bar — for one goods and one
    # stretch: the tightest scope decides, because the client intersects all
    # three and the smallest pool is the one that runs out first.
    #
    # @param item [Spree::FlashSale::Item, nil] the goods the page is about
    # @param slot [Spree::FlashSale::Slot, nil] defaults to the open one
    # @return [Hash{Symbol => Integer}] remaining units and how full the bar is
    def progress(item: nil, slot: nil, now: Time.current)
      slot ||= current_slot(now: now)
      scopes = pool_scopes(item: item, slot: slot, now: now)
      tightest = scopes.min_by { |scope| scope[:remaining] }

      return { remaining: 0, percentage: 100 } if tightest.nil? || tightest[:cap].to_i <= 0

      taken = tightest[:cap].to_i - tightest[:remaining]
      { remaining: tightest[:remaining],
        percentage: ((taken.to_f / tightest[:cap]) * 100).round.clamp(0, 100) }
    end

    # What each scope has left, as the client asks it: all time, today, this
    # stretch, and the goods' own share when the page is about one goods.
    # @return [Hash{Symbol => Integer}]
    def pool_figures(item: nil, slot: nil, now: Time.current)
      pool_scopes(item: item, slot: slot, now: now).to_h { |scope| [scope[:kind], scope[:remaining]] }
    end

    private

    def pool_scopes(item: nil, slot: nil, now: Time.current)
      slot ||= current_slot(now: now)
      scopes = [
        { kind: :all, key: 'all' },
        { kind: :day, key: "day:#{now.to_date}" },
        { kind: :slot, key: "slot:#{slot&.id}" }
      ]
      scopes << { kind: :item, key: "item:#{item.id}" } if item.present? && item.pool.to_i.positive?

      scopes.map do |scope|
        cap = Spree::FlashSale::Pool.cap_for(kind: scope[:kind], flash_sale: self, slot: slot, item: item)
        held = pools.where(kind: scope[:kind].to_s, key: scope[:key]).pick(:held).to_i
        scope.merge(cap: cap, remaining: cap - held)
      end
    end

    def ends_after_it_starts
      return if starts_at.blank? || ends_at.blank?
      return if ends_at > starts_at

      errors.add(:ends_at, :must_be_after_starts_at)
    end
  end
end
