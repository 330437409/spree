require 'spec_helper'

RSpec.describe 'POST /api/v3/store/verification_codes', type: :request do
  include_context 'API v3 Store'

  let(:phone) { '13800138000' }

  def send_code(headers: api_key_headers, **params)
    post '/api/v3/store/verification_codes', headers: headers,
         params: { phone: phone, purpose: 'account' }.merge(params)
  end

  it 'accepts a send and leaves a code behind' do
    expect { send_code }.to change(Spree::VerificationCode, :count).by(1)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body['sent']).to be true
  end

  it 'answers the client with nothing it could use as a code' do
    send_code

    expect(response.parsed_body.keys).to eq(%w[sent])
  end

  it 'enqueues the message rather than waiting for the vendor' do
    expect { send_code }.to have_enqueued_job(Spree::Notifications::DeliverJob)
  end

  # Reachable before there is a session: binding a number, resetting a password
  # and registering all happen before one.
  it 'answers a guest' do
    send_code

    expect(response).to have_http_status(:accepted)
  end

  # The answer must not be a way to ask who shops here, and a number that has
  # asked too often is answered the same way as the rest.
  it 'answers the same for a registered number, a stranger’s and one asking too often' do
    create(:customer, phone: phone)

    send_code
    registered = response.parsed_body

    send_code(phone: '13900139000')
    stranger = response.parsed_body

    3.times { send_code(phone: '13900139001') }
    too_often = response.parsed_body

    expect(registered).to eq(stranger)
    expect(too_often).to eq(stranger)
    expect(response).to have_http_status(:accepted)
  end

  it 'refuses a purpose nothing declares' do
    send_code(purpose: 'newsletter')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['code']).to eq('parameter_invalid')
  end

  it 'refuses a channel nothing declares' do
    send_code(channel: 'carrier_pigeon')

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'refuses without a number to send to' do
    send_code(phone: nil)

    expect(response).to have_http_status(:unprocessable_content)
  end

  # The client offers a voice fallback ten seconds in, and this deployment has
  # no voice transport: accepting it would deliver another SMS while the record
  # claimed a phone call, so it is refused by name until one is configured.
  it 'refuses the voice fallback it cannot deliver' do
    send_code(channel: 'voice')

    expect(response).to have_http_status(:unprocessable_content)
    expect(Spree::VerificationCode.count).to eq(0)
  end

  describe 'a payment code' do
    it 'goes to the signed-in customer’s own number' do
      user.update!(phone: phone)

      send_code(headers: bearer_headers, purpose: 'payment')

      expect(response).to have_http_status(:accepted)
      expect(Spree::VerificationCode.last.purpose).to eq('payment')
    end

    # An endpoint anybody could aim at any number would be a way to spend this
    # store's template on strangers.
    it 'is refused for a number that is not the caller’s' do
      user.update!(phone: '13900139000')

      send_code(headers: bearer_headers, purpose: 'payment')

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']['code']).to eq('access_denied')
    end

    it 'is refused to a caller with no session at all' do
      send_code(purpose: 'payment')

      expect(response).to have_http_status(:forbidden)
    end
  end
end
