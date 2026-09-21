require 'spec_helper'

RSpec.describe Spree::PaymentPin do
  subject(:record) { create(:payment_pin, pin: '246813') }

  it 'is one per customer per store' do
    existing = create(:payment_pin, pin: '246813')

    duplicate = build(:payment_pin, store: existing.store, customer: existing.customer, pin: '135791')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:customer]).to be_present
  end

  describe 'what a PIN may be' do
    it 'accepts six digits' do
      expect(record).to be_valid
    end

    it 'refuses anything that is not six digits' do
      record.pin = '12345'

      expect(record).not_to be_valid
      expect(record.errors[:pin]).to be_present
    end

    # The client applies both of these in its own form; a client-side rule is
    # a suggestion, so they are enforced where the value is stored.
    it 'refuses six identical digits' do
      record.pin = '777777'

      expect(record).not_to be_valid
    end

    it 'refuses a straight run, up or down' do
      record.pin = '123456'
      expect(record).not_to be_valid

      record.pin = '654321'
      expect(record).not_to be_valid
    end

    it 'accepts a run that is broken anywhere' do
      record.pin = '123457'

      expect(record).to be_valid
    end
  end

  describe '#verify' do
    it 'accepts the PIN it was set with' do
      expect(record.verify('246813')).to be true
    end

    it 'refuses another, and counts it' do
      expect(record.verify('999999')).to be false
      record.record_failed_attempt!

      expect(record.reload.failed_attempts).to eq(1)
    end

    # Five wrong guesses, then half an hour: the lockout is what makes a
    # six-digit secret worth having.
    it 'locks after the fifth wrong guess and refuses even the right one' do
      5.times { record.record_failed_attempt! }

      expect(record.reload).to be_locked
      expect(record.verify('246813')).to be false
    end

    it 'lets the customer back in once the window passes' do
      record.record_failed_attempt!
      record.update!(locked_until: 1.minute.ago)

      expect(record).not_to be_locked
      expect(record.verify('246813')).to be true
    end

    it 'clears the count once a guess is right' do
      2.times { record.record_failed_attempt! }

      expect(record.verify('246813')).to be true
      expect(record.reload.failed_attempts).to eq(0)
      expect(record.locked_until).to be_nil
    end
  end
end
