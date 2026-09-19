require 'spec_helper'

RSpec.describe Spree::FlashSaleTicket do
  let(:store) { @default_store }
  let(:flash_sale) { create(:flash_sale, store: store, pool_all: 5) }
  let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 5) }
  let(:variant) { create(:variant).tap { |record| record.stock_levels.update_all(count_on_hand: 5, backorderable: false) } }
  let(:item) { create(:flash_sale_item, flash_sale: flash_sale, variant: variant, pool: 5) }
  let(:customer) { create(:customer) }

  def claim(quantity: 3, **overrides)
    Spree::FlashSales::ClaimTicket.call(customer: customer, item: item, quantity: quantity, slot: slot, **overrides)
  end

  # Every scope holds the same units, so one counter answers for all of them.
  def held
    flash_sale.pools.find_by(kind: 'all')&.held.to_i
  end

  # The ticket is what expires. A hold released on its own would hand the units
  # back while the ticket still claimed them, so the lapse has to take the ticket
  # with it — status, units and the queue's mark all at once.
  describe 'a claim whose window has closed' do
    it 'gives the units back and stops holding' do
      ticket = claim(quantity: 3).value
      ticket.update!(expires_at: 1.minute.ago)

      expect(ticket.release_expired!).to be(true)

      expect(ticket.reload.status).to eq('expired')
      expect(ticket.active_key).to be_nil
      expect(held).to eq(0)
    end

    it 'frees the customer to claim again' do
      claim(quantity: 3).value.tap { |ticket| ticket.update!(expires_at: 1.minute.ago) }

      expect(claim(quantity: 1)).to be_success
      expect(Spree::FlashSaleTicket.holding.count).to eq(1)
    end

    it 'stops counting against the customer’s cap' do
      flash_sale.update!(purchase_cap_all: 3)
      claim(quantity: 3).value.tap { |ticket| ticket.update!(expires_at: 1.minute.ago) }

      expect(claim(quantity: 3)).to be_success
    end

    it 'leaves a claim that has not lapsed alone' do
      ticket = claim(quantity: 1).value

      expect(ticket.release_expired!).to be_falsey
      expect(ticket.reload.status).to eq('holding')
      expect(held).to eq(1)
    end
  end

  describe 'the expiry sweep' do
    it 'releases what has lapsed and leaves what has not' do
      lapsed = claim(quantity: 2).value
      live = Spree::FlashSales::ClaimTicket.call(
        customer: create(:customer), item: item, quantity: 1, slot: slot
      ).value
      lapsed.update!(expires_at: 1.minute.ago)

      expect(described_class.release_lapsed!(described_class.lapsed_for(flash_sale))).to eq(1)

      expect(lapsed.reload.status).to eq('expired')
      expect(live.reload.status).to eq('holding')
      expect(held).to eq(1)
    end

    it 'runs as a job over every store' do
      claim(quantity: 2).value.update!(expires_at: 1.minute.ago)

      Spree::FlashSales::ExpireTicketsJob.perform_now

      expect(Spree::FlashSaleTicket.holding.count).to eq(0)
      expect(held).to eq(0)
    end
  end
end
