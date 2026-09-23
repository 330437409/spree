require 'spec_helper'

RSpec.describe Spree::Transfer, type: :model do
  let(:store) { @default_store }
  let(:giver) { create(:customer) }

  before do
    stub_const('TransferableGiftCard', Class.new(Spree::GiftCard) do
      # Otherwise the polymorphic column stores the parent's name.
      def self.polymorphic_name = name

      def on_transfer_given(_transfer); end
      def on_transfer_accepted(_transfer); end
      def on_transfer_canceled(_transfer); end
    end)
  end

  # A real model, not a double: a polymorphic column stores its class's name, the
  # primitive asks that class about prefixed ids, and a record reread from the
  # database has to answer the contract all the same.
  def thing = TransferableGiftCard.create!(store: store, amount: 10)

  def build_transfer(**attributes)
    build(:transfer, from_customer: giver, transferable: thing, **attributes)
  end

  describe 'the journey' do
    it 'is born pending, with a token nobody could guess' do
      row = build_transfer
      row.save!

      expect(row).to be_pending
      expect(row.token.length).to be >= 24
    end

    it 'holds where it is going and why' do
      row = create(:transfer, from_customer: giver, transferable: thing, to_phone: '13800000000',
                              message: '生日快乐')

      expect(row.to_phone).to eq('13800000000')
      expect(row.message).to eq('生日快乐')
      expect(row.to_customer).to be_nil
    end

    # Expiry is a date fact, never a stored status — the same rule a gift card
    # follows — so a reader is told `expired` while the column still says pending.
    it 'reads a closed window as expired' do
      row = create(:transfer, from_customer: giver, transferable: thing, expires_at: 1.hour.ago)

      expect(row).to be_expired
      expect(row.display_status).to eq('expired')
      expect(row.reload.status).to eq('pending')
    end
  end

  describe 'the scopes a client reads' do
    # The status scope is the window: a pending row nobody may act on any more is
    # not pending, which is what every 赠送中 read comes through.
    it 'leaves a closed window out of the pending scope' do
      open_window = create(:transfer, from_customer: giver, transferable: thing, expires_at: 1.day.from_now)
      closed = create(:transfer, from_customer: giver, transferable: thing, expires_at: 1.hour.ago)

      expect(described_class.pending).to include(open_window)
      expect(described_class.pending).not_to include(closed)
      expect(described_class.open_windows).not_to include(closed)
    end

    it 'finds what is about to lapse' do
      soon = create(:transfer, from_customer: giver, transferable: thing, expires_at: 1.hour.from_now)
      later = create(:transfer, from_customer: giver, transferable: thing, expires_at: 1.month.from_now)

      expect(described_class.expiring_before(1.day.from_now)).to include(soon)
      expect(described_class.expiring_before(1.day.from_now)).not_to include(later)
    end

    it 'finds what a customer gave and what was given to them' do
      recipient = create(:customer)
      given = create(:transfer, from_customer: giver, transferable: thing)
      accepted = create(:transfer, from_customer: create(:customer), transferable: thing,
                                   to_customer: recipient)

      expect(described_class.for_giver(giver)).to include(given)
      expect(described_class.for_recipient(recipient)).to include(accepted)
    end
  end

  describe 'the contract' do
    it 'refuses a thing that does not answer it, by name' do
      row = build(:transfer, from_customer: giver, transferable: create(:gift_card, store: store))

      expect(row).not_to be_valid
      expect(row.errors.full_messages.to_sentence).to include('cannot be given away')
    end

    it 'accepts a thing that does' do
      expect(build_transfer).to be_valid
    end
  end

  describe 'one window at a time' do
    it 'refuses a second transfer of the same thing' do
      taken = thing
      create(:transfer, from_customer: giver, transferable: taken)

      expect(build(:transfer, from_customer: giver, transferable: taken)).not_to be_valid
    end

    # The validation is the readable half; the index is the one that holds under a
    # race. Read from the schema, which says the same thing on every adapter.
    it 'is enforced by the database too' do
      index = described_class.connection.indexes(:spree_transfers).
              find { |candidate| candidate.name == 'index_spree_transfers_on_transferable_while_pending' }

      expect(index).to be_present
      expect(index.unique).to be(true)
      expect(index.columns).to include('transferable_type', 'transferable_id').or contain_exactly('pending_key')
    end

    it 'lets the same thing travel again once its window is answered' do
      taken = thing
      first = create(:transfer, from_customer: giver, transferable: taken)
      first.update!(status: 'canceled', canceled_at: Time.current)

      expect(build(:transfer, from_customer: giver, transferable: taken)).to be_valid
    end
  end
end
