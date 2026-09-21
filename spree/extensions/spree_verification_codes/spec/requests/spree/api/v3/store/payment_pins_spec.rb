require 'spec_helper'

RSpec.describe '/api/v3/store/payment_pin', type: :request do
  include_context 'API v3 Store'

  let(:phone) { '13800138000' }

  before { user.update!(phone: phone) }

  def issue_code(value: '123456')
    create(:verification_code, store: store, phone: phone, purpose: 'payment', code: value)
  end

  describe 'reading it' do
    # A customer with no PIN is a state the settings page renders, not a 404.
    it 'answers that there is none, and that nothing is asked for' do
      get '/api/v3/store/payment_pin', headers: bearer_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('set' => false, 'required' => false)
    end

    it 'answers both facts once there is one' do
      create(:payment_pin, store: store, customer: user, pin: '246813')

      get '/api/v3/store/payment_pin', headers: bearer_headers

      expect(response.parsed_body).to eq('set' => true, 'required' => true)
    end

    it 'answers a customer who turned the prompt off' do
      create(:payment_pin, store: store, customer: user, pin: '246813', required: false)

      get '/api/v3/store/payment_pin', headers: bearer_headers

      expect(response.parsed_body).to eq('set' => true, 'required' => false)
    end

    it 'needs a session' do
      get '/api/v3/store/payment_pin', headers: api_key_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'setting it' do
    it 'sets the PIN with a code sent to the customer’s own number' do
      issue_code

      put '/api/v3/store/payment_pin', headers: bearer_headers,
          params: { code: '123456', pay_password: '246813', confirmation_password: '246813' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('set' => true, 'required' => true)
      expect(Spree::PaymentPin.find_by(store: store, customer: user).verify('246813')).to be_truthy
    end

    it 'never answers the PIN back' do
      issue_code

      put '/api/v3/store/payment_pin', headers: bearer_headers,
          params: { code: '123456', pay_password: '246813' }

      expect(response.body).not_to include('246813')
    end

    it 'refuses a wrong code as a field error' do
      issue_code

      put '/api/v3/store/payment_pin', headers: bearer_headers,
          params: { code: '999999', pay_password: '246813' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['details']).to have_key('code')
    end

    it 'refuses a PIN six identical digits' do
      issue_code

      put '/api/v3/store/payment_pin', headers: bearer_headers,
          params: { code: '123456', pay_password: '111111' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['details']).to have_key('pin')
    end

    it 'refuses a mismatched confirmation' do
      issue_code

      put '/api/v3/store/payment_pin', headers: bearer_headers,
          params: { code: '123456', pay_password: '246813', confirmation_password: '135791' }

      expect(response.parsed_body['error']['details']).to have_key('pin_confirmation')
    end
  end

  describe 'the required switch' do
    let!(:record) { create(:payment_pin, store: store, customer: user, pin: '246813') }

    it 'turns the prompt off without a code, which is what the settings page does' do
      patch '/api/v3/store/payment_pin', headers: bearer_headers, params: { required: false }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('set' => true, 'required' => false)
      expect(record.reload.required).to be false
    end

    it 'turns it back on' do
      record.update!(required: false)

      patch '/api/v3/store/payment_pin', headers: bearer_headers, params: { required: true }

      expect(response.parsed_body).to eq('set' => true, 'required' => true)
    end

    it 'refuses without the flag rather than reading its absence as false' do
      patch '/api/v3/store/payment_pin', headers: bearer_headers, params: {}

      expect(response).to have_http_status(:unprocessable_content)
      expect(record.reload.required).to be true
    end

    it 'answers a customer with no PIN as having none' do
      record.destroy

      patch '/api/v3/store/payment_pin', headers: bearer_headers, params: { required: true }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'closing it' do
    let!(:record) { create(:payment_pin, store: store, customer: user, pin: '246813') }

    # Closing is not deleting: the PIN stays, so turning it back on does not
    # mean thinking up another one.
    it 'stops asking for it and keeps it' do
      issue_code

      delete '/api/v3/store/payment_pin', headers: bearer_headers,
             params: { code: '123456', pay_password: '246813' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('set' => true, 'required' => false)
      expect(record.reload.pin_digest).to be_present
    end

    it 'refuses without the PIN the customer has now' do
      issue_code

      delete '/api/v3/store/payment_pin', headers: bearer_headers,
             params: { code: '123456', pay_password: '999999' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(record.reload.required).to be true
    end

    it 'refuses without a code' do
      delete '/api/v3/store/payment_pin', headers: bearer_headers, params: { pay_password: '246813' }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
