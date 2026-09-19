require 'spec_helper'

RSpec.describe Spree::FlashSale do
  let(:flash_sale) { create(:flash_sale, pool_all: 10, pool_per_day: 10, pool_per_slot: 5) }

  it 'answers its window from the clock rather than from the stored status' do
    expect(flash_sale.window_status(now: Time.current)).to eq('live')
    expect(flash_sale.window_status(now: flash_sale.starts_at - 1.minute)).to eq('scheduled')
    expect(flash_sale.window_status(now: flash_sale.ends_at + 1.second)).to eq('ended')
  end

  it 'refuses a window that ends before it starts' do
    flash_sale.ends_at = flash_sale.starts_at - 1.minute

    expect(flash_sale).not_to be_valid
    expect(flash_sale.errors[:ends_at]).to be_present
  end

  # The slot's own cap is optional: a slot that sets none inherits the
  # activity's, and zero is "unset" here rather than "nothing left".
  describe 'a slot with no pool of its own' do
    it 'inherits the activity’s per-slot figure' do
      slot = create(:flash_sale_slot, flash_sale: flash_sale, pool: 0)

      expect(slot.flash_sale.pool_figures(slot: slot).fetch(:slot)).to eq(5)
    end
  end

  # Removing an activity or one of its slots has to work: a dependent
  # association with a wrong inverse raises the moment it is used.
  it 'can be removed, with its slots and their counters' do
    slot = create(:flash_sale_slot, flash_sale: flash_sale)
    Spree::FlashSale::Pool.for!(flash_sale: flash_sale, kind: 'slot', slot: slot)

    expect { slot.destroy! }.not_to raise_error
    expect { flash_sale.destroy! }.not_to raise_error
  end
end
