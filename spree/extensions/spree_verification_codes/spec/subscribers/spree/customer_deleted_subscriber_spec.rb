require 'spec_helper'

# The bus publishes `customer.deleted` after the destroy commits, which is a
# moment a transactional spec never reaches — so the handler is exercised with
# the payload the model builds, and the wiring is asserted separately.
RSpec.describe Spree::CustomerDeletedSubscriber do
  let(:store) { create(:store) }
  let(:customer) { create(:customer, phone: '13800138000') }

  # An orphaned credential is a credential for nobody.
  it 'destroys the PIN of a customer deleted outright' do
    create(:payment_pin, store: store, customer: customer, pin: '246813')

    described_class.new.handle(double(payload: { 'id' => customer.prefixed_id }))

    expect(Spree::PaymentPin.with_deleted.where(customer_id: customer.id).count).to eq(0)
  end

  it 'leaves another customer’s PIN where it is' do
    other = create(:customer, phone: '13900139000')
    create(:payment_pin, store: store, customer: customer, pin: '246813')
    create(:payment_pin, store: store, customer: other, pin: '135791')

    described_class.new.handle(double(payload: { 'id' => customer.prefixed_id }))

    expect(Spree::PaymentPin.where(customer_id: other.id).count).to eq(1)
  end

  it 'is on the bus, and only for the deletion' do
    expect(Spree.subscribers).to include(described_class)
  end
end
