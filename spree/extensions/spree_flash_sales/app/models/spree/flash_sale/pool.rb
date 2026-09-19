module Spree
  class FlashSale
    # One scope of an activity's pool — all time, one day, one slot, one item —
    # and what has been claimed against it.
    #
    # The cap stays on the record a merchant edits rather than being copied
    # here, so raising a pool takes effect the moment it is saved; this row is
    # only the counter. Reserving is one guarded statement, because two
    # customers claiming the last unit must not both succeed.
    class Pool < Spree.base_class
      KINDS = %w[all day slot item].freeze

      belongs_to :flash_sale, class_name: 'Spree::FlashSale', inverse_of: :pools
      belongs_to :slot, class_name: 'Spree::FlashSale::Slot', optional: true
      belongs_to :item, class_name: 'Spree::FlashSale::Item', optional: true
      has_many :holds, class_name: 'Spree::PoolHold', dependent: :destroy, inverse_of: :pool

      validates :kind, presence: true, inclusion: { in: KINDS }
      validates :key, presence: true, uniqueness: { scope: [:flash_sale_id, *spree_base_uniqueness_scope] }

      # The counter for one scope, created on first use.
      # @return [Spree::FlashSale::Pool]
      def self.for!(flash_sale:, kind:, on_date: nil, slot: nil, item: nil)
        key = key_for(kind: kind, on_date: on_date, slot: slot, item: item)

        find_or_create_by!(flash_sale: flash_sale, key: key) do |pool|
          pool.kind = kind.to_s
          pool.on_date = on_date
          pool.slot = slot
          pool.item = item
        end
      rescue ActiveRecord::RecordNotUnique
        find_by!(flash_sale: flash_sale, key: key)
      end

      # @return [String] the identity a counter is unique by, in one column so
      #   the index holds on every engine — a composite over three nullable
      #   columns would not, because NULLs are distinct to a unique index
      def self.key_for(kind:, on_date: nil, slot: nil, item: nil)
        case kind.to_s
        when 'all' then 'all'
        when 'day' then "day:#{on_date}"
        when 'slot' then "slot:#{slot&.id}"
        when 'item' then "item:#{item&.id}"
        end
      end

      # @return [Integer] the units this scope allows, zero when it allows none
      def cap
        case kind
        when 'all' then flash_sale.pool_all
        when 'day' then flash_sale.pool_per_day
        when 'slot' then slot&.pool || flash_sale.pool_per_slot
        when 'item' then item&.pool
        end.to_i
      end

      def remaining
        cap - held
      end

      # @param quantity [Integer]
      # @return [Boolean] whether the units were taken; false means this scope
      #   has not got them, and nothing changed
      def reserve!(quantity)
        quantity = quantity.to_i
        return false if quantity <= 0

        self.class.where(id: id).where(held: ..(cap - quantity)).
          update_all(['held = held + ?', quantity]).positive?
      end

      # @return [Boolean] whether the units were given back
      def release!(quantity)
        quantity = quantity.to_i
        return false if quantity <= 0

        self.class.where(id: id).where('held >= ?', quantity).
          update_all(['held = held - ?', quantity]).positive?
      end
    end
  end
end
