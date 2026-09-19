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
    STATUSES = %w[scheduled live ended].freeze

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :seller, class_name: 'Spree::Seller', optional: true
    has_many :slots, class_name: 'Spree::FlashSale::Slot', dependent: :destroy, inverse_of: :flash_sale
    has_many :items, class_name: 'Spree::FlashSale::Item', dependent: :destroy, inverse_of: :flash_sale
    has_many :pools, class_name: 'Spree::FlashSale::Pool', dependent: :destroy, inverse_of: :flash_sale
    has_many :tickets, class_name: 'Spree::FlashSaleTicket', dependent: :destroy, inverse_of: :flash_sale
    has_many :reminders, class_name: 'Spree::FlashSale::Reminder', dependent: :destroy, inverse_of: :flash_sale

    normalizes :code, with: ->(value) { value.to_s.strip.presence }

    validates :title, :code, :status, :starts_at, :ends_at, presence: true
    validates :code, inclusion: { in: CODES }
    validates :status, inclusion: { in: STATUSES }
    validate :ends_after_it_starts

    scope :scheduled, -> { where(status: 'scheduled') }
    scope :live_now, -> { where(status: 'live') }

    # What the window says, from the server's clock. `ended` is not a state the
    # reads render: an activity whose window has closed is simply not offered.
    # @param now [Time]
    # @return [String] scheduled, live or ended
    def window_status(now: Time.current)
      return 'ended' if ends_at <= now
      return 'live' if starts_at <= now

      'scheduled'
    end

    def live?(now: Time.current)
      window_status(now: now) == 'live'
    end

    # The slot whose window is open, which is the one a claim belongs to when
    # the client names none.
    # @return [Spree::FlashSale::Slot, nil]
    def current_slot(now: Time.current)
      slots.select { |slot| slot.starts_at <= now && slot.ends_at > now }.min_by(&:position)
    end

    # How much of the activity is left, in every scope the client intersects:
    # the smallest remaining pool wins, and zero means sold out.
    # @return [Integer]
    def remaining_pools(now: Time.current)
      scopes = [pool_remaining(:all), pool_remaining(:day, on_date: now.to_date), pool_remaining(:slot)]
      scopes = scopes.compact
      return 0 if scopes.empty?

      scopes.min
    end

    # @return [Integer, nil] units left in one scope, nil when the scope has no
    #   cap at all
    def pool_remaining(kind, on_date: nil, slot: nil)
      cap = pool_cap(kind, slot: slot)
      return nil if cap.nil?

      cap - pools.where(kind: kind.to_s, key: pool_key(kind, on_date: on_date, slot: slot)).pick(:held).to_i
    end

    def pool_cap(kind, slot: nil)
      case kind.to_s
      when 'all' then pool_all
      when 'day' then pool_per_day
      when 'slot' then (slot || current_slot)&.pool || pool_per_slot
      end
    end

    def pool_key(kind, on_date: nil, slot: nil)
      case kind.to_s
      when 'all' then 'all'
      when 'day' then "day:#{on_date}"
      when 'slot' then "slot:#{(slot || current_slot)&.id}"
      end
    end

    private

    def ends_after_it_starts
      return if starts_at.blank? || ends_at.blank?
      return if ends_at > starts_at

      errors.add(:ends_at, :must_be_after_starts_at)
    end
  end
end
