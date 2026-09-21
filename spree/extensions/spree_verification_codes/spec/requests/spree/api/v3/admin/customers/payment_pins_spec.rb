require 'spec_helper'

RSpec.describe 'DELETE /api/v3/admin/customers/:customer_id/payment_pin', type: :request do
  include_context 'API v3 Admin authenticated'

  let(:customer) { create(:customer, phone: '13800138000') }
  let!(:record) { create(:payment_pin, store: store, customer: customer, pin: '246813') }

  # A customer the store knows is one who has shopped here.
  before { create(:order, store: store, customer: customer) }

  def unlock(headers: self.headers, customer_id: customer.prefixed_id)
    delete "/api/v3/admin/customers/#{customer_id}/payment_pin", headers: headers
  end

  # A lockout with no way out is a support hole rather than a security
  # control, and the alternative to this route is editing the database.
  it 'clears the credential so the customer can set a new one' do
    5.times { record.record_failed_attempt! }
    expect(record.reload).to be_locked

    expect { unlock }.to change(Spree::PaymentPin, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end

  it 'answers a customer who has no PIN as having none' do
    record.destroy

    unlock

    expect(response).to have_http_status(:not_found)
  end

  # The PIN is the store's row and the customer is only reachable through it:
  # another store's operator cannot clear a credential they do not hold.
  it 'refuses a customer who has never shopped here' do
    elsewhere = create(:customer, phone: '13900139000')

    unlock(customer_id: elsewhere.prefixed_id)

    expect(response).to have_http_status(:not_found)
    expect(Spree::PaymentPin.count).to eq(1)
  end

  it 'needs the admin API' do
    delete "/api/v3/admin/customers/#{customer.prefixed_id}/payment_pin",
           headers: { 'x-spree-api-key' => create(:api_key, :publishable, store: store).token }

    expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
    expect(Spree::PaymentPin.count).to eq(1)
  end
end
