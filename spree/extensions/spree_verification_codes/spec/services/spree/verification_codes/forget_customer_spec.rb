require 'spec_helper'

# Erasure is the flow's job and these rows are this gem's, so the flow's own
# hooks are where they are forgotten. The core schema guard cannot see an
# extension's tables, which is why this spec exists here.
RSpec.describe SpreeVerificationCodes::ForgetCustomer do
  let(:store) { create(:store) }
  let(:customer) { create(:customer, phone: '13800138000') }

  before do
    create(:payment_pin, store: store, customer: customer, pin: '246813')
    create(:verification_code, store: store, phone: customer.phone, purpose: 'account')
  end

  # The flow's own steps rewrite the number before its hooks run, so the phone
  # is remembered while it is still there.
  # A plain double rather than a verified one: the flow's argument readers are
  # defined dynamically from its `perform` signature, which an instance double
  # cannot see.
  def erase
    workflow = double('workflow', customer: customer)
    SpreeVerificationCodes::ForgetCustomer::RememberPhone.call(workflow)
    customer.update_columns(phone: nil)
    described_class.call(workflow)
  end

  it 'destroys the PIN rather than leaving a credential behind the account' do
    erase

    expect(Spree::PaymentPin.count).to eq(0)
  end

  # Soft-deleted rows keep the phone in the table, which is the fact being
  # erased — so these are deleted, not marked.
  it 'deletes the codes sent to the erased number, phone and all' do
    erase

    expect(Spree::VerificationCode.with_deleted.where(phone: '13800138000').count).to eq(0)
  end

  it 'is registered against the flow it extends' do
    expect(Spree.hooks.for('customers.anonymize.after_anonymize')).to include(described_class)
  end
end
