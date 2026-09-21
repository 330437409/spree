require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::Orders::CancellationsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:store) { @default_store }
  let!(:order) { create(:completed_order_with_totals, store: store, customer: user) }
  let(:reason) { create(:order_cancellation_reason, store: store, name: 'Changed my mind') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  def cancel(params = {})
    post :create, params: { order_id: order.prefixed_id }.merge(params), as: :json
  end

  it 'calls the order off and stamps why, leaving the staff actor columns alone' do
    cancel(reason_id: reason.prefixed_id, note: 'Found it cheaper elsewhere')

    expect(response).to have_http_status(:ok)
    expect(order.reload.status).to eq('canceled')
    expect(order.canceled_at).to be_present
    expect(order.cancel_reason).to eq(reason)
    expect(order.cancel_note).to eq('Found it cheaper elsewhere')
    # The actor columns are for staff and system identities — this codebase
    # registers admins and API keys, not customers — so a customer's own
    # cancellation leaves them alone.
    expect(order.canceler_id).to be_nil
    expect(json_response['status']).to eq('canceled')
  end

  # The button and the write read the same question: an order that can no
  # longer be called off answers so on the payload, and is refused if the write
  # arrives anyway (a parcel dispatched in between).
  it 'stops offering the cancellation once the order has been dispatched' do
    order.update_columns(fulfillment_status: 'shipped')

    cancel

    expect(response).to have_http_status(:unprocessable_content)
    expect(order.reload.status).not_to eq('canceled')
  end

  it 'refuses a reason belonging to another store' do
    other_reason = create(:order_cancellation_reason, store: create(:store))

    cancel(reason_id: other_reason.prefixed_id)

    expect(order.reload.cancel_reason_id).to be_nil
  end

  # Somebody else's order is not one this customer can see, let alone call off.
  it 'answers 404 for an order that is not theirs' do
    someone_elses = create(:completed_order_with_totals, store: store, customer: create(:user))

    post :create, params: { order_id: someone_elses.prefixed_id }, as: :json

    expect(response).to have_http_status(:not_found)
    expect(someone_elses.reload.status).not_to eq('canceled')
  end

  it 'requires a signed-in customer' do
    request.headers['Authorization'] = nil

    cancel

    expect(response).to have_http_status(:unauthorized)
  end
end
