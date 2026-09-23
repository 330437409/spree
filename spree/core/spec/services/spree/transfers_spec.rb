require 'spec_helper'

RSpec.describe Spree::Transfers do
  let(:store) { @default_store }
  let(:giver) { create(:customer) }
  let(:recipient) { create(:customer) }
  let(:calls) { [] }

  # Real models, not doubles: a polymorphic column stores the class's name, the
  # primitive asks that class about prefixed ids, and the thing is reread from
  # the database on the way — so its contract has to live on the class.
  before do
    stub_const('TransferableGiftCard', Class.new(Spree::GiftCard) do
      class << self
        # Otherwise the polymorphic column stores the parent's name and every
        # reread answers as a plain gift card, contract and all.
        def polymorphic_name = name
        def calls = @calls ||= []
        def reset! = @calls = []
      end

      def on_transfer_given(transfer) = self.class.calls << [:given, transfer.id]
      def on_transfer_accepted(transfer) = self.class.calls << [:accepted, transfer.id]
      def on_transfer_canceled(transfer) = self.class.calls << [:canceled, transfer.id]
    end)

    # It can be given away, and it refuses when somebody tries to claim it — a
    # card that turns out to have lapsed in between.
    stub_const('RefusingGiftCard', Class.new(Spree::GiftCard) do
      def self.polymorphic_name = name

      def on_transfer_given(_transfer); end
      def on_transfer_accepted(_transfer) = raise(Spree::Transfers::Refused, 'already lapsed')
      def on_transfer_canceled(_transfer); end
    end)

    # And one that refuses at give time: nobody may hand it over at all.
    stub_const('UngiftableGiftCard', Class.new(Spree::GiftCard) do
      def self.polymorphic_name = name

      def on_transfer_given(_transfer) = raise(Spree::Transfers::Refused, 'not this one')
      def on_transfer_accepted(_transfer); end
      def on_transfer_canceled(_transfer); end
    end)

    TransferableGiftCard.reset!
  end

  def calls = TransferableGiftCard.calls

  def thing = TransferableGiftCard.create!(store: store, amount: 10)

  def refusing = RefusingGiftCard.create!(store: store, amount: 10)

  def ungiftable = UngiftableGiftCard.create!(store: store, amount: 10)

  def untransferable = Spree::GiftCard.create!(store: store, amount: 10)

  def give!(transferable, expires_in: 7.days)
    described_class.give!(from: giver, transferable: transferable, to_phone: '13800000000',
                         expires_at: expires_in.from_now)
  end

  describe 'giving something away' do
    it 'opens a window and tells the thing it is on its way' do
      given = thing

      result = give!(given)

      expect(result).to be_success
      expect(result.value).to be_pending
      expect(result.value.to_phone).to eq('13800000000')
      expect(calls).to eq([[:given, result.value.id]])
    end

    it 'refuses a thing that cannot be given away' do
      expect(give!(untransferable)).to be_failure
      expect(Spree::Transfer.count).to eq(0)
    end

    it 'refuses a second window on the same thing' do
      given = thing
      give!(given)

      expect(give!(given)).to be_failure
      expect(Spree::Transfer.count).to eq(1)
    end

    # The thing may refuse at give time — a card that turns out not to be
    # giftable — and the row must not survive the refusal.
    it 'writes nothing when the thing refuses' do
      expect(give!(ungiftable)).to be_failure
      expect(Spree::Transfer.count).to eq(0)
    end

    it 'refuses a window that would open already closed' do
      expect(give!(thing, expires_in: -1.hour)).to be_failure
      expect(Spree::Transfer.count).to eq(0)
    end

    # A window nobody claimed does not hold the thing forever: the row stays as
    # the record of the gift, softly deleted, and the next give is free to open
    # another.
    it 'clears a lapsed window and gives the thing again' do
      given = thing
      first = give!(given, expires_in: 1.minute).value
      first.update_columns(expires_at: 1.hour.ago)

      result = give!(given)

      expect(result).to be_success
      expect(result.value).to be_pending
      expect(first.reload).to be_deleted
      expect(Spree::Transfer.with_deleted.count).to eq(2)
    end
  end

  describe 'claiming it' do
    it 'moves it to the customer, and tells the thing it arrived' do
      given = thing
      transfer = give!(given).value

      result = described_class.accept!(transfer, customer: recipient)

      expect(result).to be_success
      expect(result.value).to be_accepted
      expect(result.value.to_customer).to eq(recipient)
      expect(result.value.accepted_at).to be_present
      expect(calls).to include([:accepted, transfer.id])
    end

    # A phone that lost its connection sends the claim twice.
    it 'answers a claim that already happened with the same transfer' do
      transfer = give!(thing).value
      first = described_class.accept!(transfer, customer: recipient).value

      expect(described_class.accept!(first, customer: recipient).value).to eq(first)
    end

    # The link is a bearer capability and a bearer hands it on: the second
    # customer is told somebody got there first rather than being answered with a
    # success for a card they do not hold.
    it 'refuses a claim by somebody who is not the one who claimed it' do
      transfer = give!(thing).value
      described_class.accept!(transfer, customer: recipient)

      result = described_class.accept!(transfer.reload, customer: create(:customer))

      expect(result).to be_failure
      expect(transfer.reload.to_customer).to eq(recipient)
    end

    # The thing can be gone by the time somebody claims — an admin cleanup, a
    # deletion request — and the claim must not report a success for it.
    it 'refuses when the thing being claimed no longer exists' do
      given = thing
      transfer = give!(given).value
      given.destroy

      result = described_class.accept!(transfer.reload, customer: recipient)

      expect(result).to be_failure
      expect(transfer.reload).to be_pending
    end

    it 'refuses a window that has closed' do
      transfer = give!(thing, expires_in: 1.minute).value
      transfer.update_columns(expires_at: 1.hour.ago)

      expect(described_class.accept!(transfer.reload, customer: recipient)).to be_failure
      expect(transfer.reload).to be_pending
    end

    # The thing's own transition runs inside the service's transaction: a refusal
    # takes the acceptance with it, so nobody ends up holding nothing.
    it 'moves nothing when the thing refuses at claim time' do
      transfer = give!(refusing).value

      result = described_class.accept!(transfer, customer: recipient)

      expect(result).to be_failure
      expect(transfer.reload).to be_pending
      expect(transfer.to_customer).to be_nil
    end

    # And it holds when a caller is already inside a transaction of its own — a
    # workflow, another domain's service. The claim runs in a savepoint for
    # exactly this, since a plain nested transaction would join the caller's and
    # swallow the rollback.
    it 'moves nothing when the caller wrapped the claim in its own transaction' do
      transfer = give!(refusing).value

      result = ActiveRecord::Base.transaction do
        described_class.accept!(transfer, customer: recipient)
      end

      expect(result).to be_failure
      expect(transfer.reload).to be_pending
      expect(transfer.to_customer).to be_nil
    end
  end

  describe 'taking it back' do
    it 'closes the window and tells the thing it came home' do
      given = thing
      transfer = give!(given).value

      result = described_class.cancel!(transfer)

      expect(result).to be_success
      expect(result.value).to be_canceled
      expect(result.value.canceled_at).to be_present
      expect(calls).to include([:canceled, transfer.id])
    end

    it 'answers a cancellation that already happened' do
      transfer = give!(thing).value
      first = described_class.cancel!(transfer).value

      expect(described_class.cancel!(first).value).to eq(first)
    end

    it 'refuses to take back what somebody already claimed' do
      transfer = give!(thing).value
      described_class.accept!(transfer, customer: recipient)

      expect(described_class.cancel!(transfer.reload)).to be_failure
    end

    # The gift nobody opened: past its date but still `pending`, which is the
    # only state from which it can be taken back at all — and taking it back is
    # what stops it holding the thing.
    it 'takes back a window whose date has passed' do
      transfer = give!(thing, expires_in: 1.minute).value
      transfer.update_columns(expires_at: 1.hour.ago)

      result = described_class.cancel!(transfer.reload)

      expect(result).to be_success
      expect(result.value).to be_canceled
    end
  end
end
