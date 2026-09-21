require 'spec_helper'

RSpec.describe Spree::VerificationCode do
  let(:store) { create(:store) }
  let(:phone) { '13800138000' }

  def issue(purpose: 'account', code: '123456', **attrs)
    create(:verification_code, store: store, phone: phone, purpose: purpose, code: code, **attrs)
  end

  describe 'the number a code is keyed by' do
    it 'reads every spelling of a Chinese mobile as one number' do
      expect(described_class.normalize_phone('+86 138-0013-8000')).to eq(phone)
      expect(described_class.normalize_phone('8613800138000')).to eq(phone)
      expect(described_class.normalize_phone(phone)).to eq(phone)
    end

    it 'leaves a number that is not a Chinese mobile alone' do
      expect(described_class.normalize_phone('1 555 010 9999')).to eq('15550109999')
    end

    it 'answers nil for nothing at all' do
      expect(described_class.normalize_phone(nil)).to eq('')
    end
  end

  describe '.usable_for' do
    it 'answers the code the number may still be proved with' do
      code = issue

      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to eq(code)
    end

    it 'answers nothing once the code is spent' do
      code = issue
      code.update!(consumed_at: Time.current)

      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to be_nil
    end

    # Asking for another code replaces the one before it: two live codes for
    # one number is one more way in than anybody needs.
    it 'answers the newest code, not an older one still in its window' do
      issue(code: '111111')
      newest = issue(code: '222222')

      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to eq(newest)
    end

    it 'answers nothing for the other purpose family' do
      issue(purpose: 'payment')

      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to be_nil
    end

    it 'answers nothing past the store’s attempt limit' do
      code = issue

      store.preferred_verification_code_max_attempts.times { code.check!('000000') }

      expect(code.reload).not_to be_usable
      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to be_nil
    end

    it 'answers nothing once it has expired' do
      issue(expires_at: 1.minute.ago)

      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to be_nil
    end
  end

  # Tenancy is part of the question: a code this store issued is the only code
  # it accepts, and a store column that is written and never read is a tenancy
  # the next reader would believe in.
  describe 'the store a code belongs to' do
    it 'answers nothing for a code another store issued' do
      create(:verification_code, store: create(:store), phone: phone, purpose: 'account')

      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to be_nil
    end

    it 'refuses to spend one' do
      create(:verification_code, store: create(:store), phone: phone, purpose: 'account', code: '123456')

      expect(described_class.consume(store: store, phone: phone, purpose: 'account', code: '123456')).to be_nil
    end
  end

  # Asking for another code replaces the one before it — including after the
  # new one is spent, or one message would certify two writes.
  describe 'a code that was replaced' do
    it 'is not usable once the newer one has been spent' do
      older = issue(code: '111111')
      newer = issue(code: '222222')
      described_class.consume(store: store, phone: phone, purpose: 'account', code: '222222')

      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to be_nil
      expect(described_class.consume(store: store, phone: phone, purpose: 'account', code: '111111')).to be_nil
      expect(older.reload.consumed_at).to be_nil
    end
  end

  describe '#check!' do
    it 'records that the code was proved, without spending it' do
      code = issue

      expect(code.check!('123456')).to be true
      expect(code.reload.verified_at).to be_present
      expect(code.consumed_at).to be_nil
    end

    # The client posts the same code twice by design, so a check that spent it
    # would break the flow it exists for.
    it 'can be proved more than once' do
      code = issue

      2.times { expect(code.check!('123456')).to be true }
      expect(code.reload.consumed_at).to be_nil
    end

    it 'counts a wrong guess against the code' do
      code = issue

      expect(code.check!('999999')).to be false
      expect(code.reload.attempts).to eq(1)
      expect(code.verified_at).to be_nil
    end
  end

  describe '.consume' do
    # The check does not consume; this does, and only once — which is what
    # makes a code usable by exactly one write.
    it 'spends the code, and refuses the second spend' do
      issue

      expect(described_class.consume(store: store, phone: phone, purpose: 'account', code: '123456')).to be_present
      expect(described_class.consume(store: store, phone: phone, purpose: 'account', code: '123456')).to be_nil
    end

    it 'refuses a code that does not match' do
      issue

      expect(described_class.consume(store: store, phone: phone, purpose: 'account', code: '999999')).to be_nil
      expect(described_class.usable_for(store: store, phone: phone, purpose: 'account')).to be_present
    end

    # A code issued for the PIN is not a code for the account flows, and the
    # other way round.
    it 'refuses a code issued for the other family' do
      issue(purpose: 'payment')

      expect(described_class.consume(store: store, phone: phone, purpose: 'account', code: '123456')).to be_nil
      expect(described_class.consume(store: store, phone: phone, purpose: 'payment', code: '123456')).to be_present
    end

    it 'reads any spelling of the number as the same number' do
      issue

      expect(described_class.consume(store: store, phone: '+86 138-0013-8000', purpose: 'account', code: '123456')).to be_present
    end
  end

  it 'keeps a digest and never the code itself' do
    code = issue

    expect(code.code_digest).to be_present
    expect(code.code_digest).not_to include('123456')
    expect(code.authenticate_code('123456')).to be_truthy
  end
end
