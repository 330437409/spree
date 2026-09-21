require 'spec_helper'

# The two account flows that spend a code, end to end: the customer write that
# changes a phone, and the erasure request that confirms a passwordless
# account. They live here rather than in spree/api because only a deployment
# with this gem installed has the service those writes ask
# (docs/plans/6.1-phone-verification-and-payment-pin.md).
RSpec.describe 'the account flows that spend a code', type: :request do
  include_context 'API v3 Store'

  let(:phone) { '13800138000' }

  def issue_code(value: '123456', purpose: 'account', to: phone)
    create(:verification_code, store: store, phone: to, purpose: purpose, code: value)
  end

  describe 'changing the phone' do
    it 'writes the number a code was sent to' do
      issue_code(value: '123456', to: '13900139000')

      patch '/api/v3/store/customers/me', headers: bearer_headers,
            params: { phone: '13900139000', code: '123456' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.phone).to eq('13900139000')
    end

    it 'spends the code, so it cannot be replayed onto a second write' do
      issue_code(value: '123456', to: '13900139000')

      patch '/api/v3/store/customers/me', headers: bearer_headers, params: { phone: '13900139000', code: '123456' }
      patch '/api/v3/store/customers/me', headers: bearer_headers, params: { phone: '13700137000', code: '123456' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['code']).to eq('verification_code_invalid')
      expect(user.reload.phone).to eq('13900139000')
    end

    # Without this the customer write is a way to claim any number at all.
    it 'refuses a number with no code at all' do
      was = user.phone

      patch '/api/v3/store/customers/me', headers: bearer_headers, params: { phone: '13900139000' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.phone).to eq(was)
    end

    # A value with no digits in it is no number, whatever it looks like: read
    # as one, it would let a session take a junk "number" and then pass the
    # erasure bar with it.
    it 'refuses a value that has no digits in it' do
      patch '/api/v3/store/customers/me', headers: bearer_headers, params: { phone: '+' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.phone).to be_present
    end

    it 'reads a number the account already holds as no change, and asks for nothing' do
      user.update!(phone: phone)

      patch '/api/v3/store/customers/me', headers: bearer_headers, params: { phone: '+86 138 0013 8000' }

      expect(response).to have_http_status(:ok)
    end

    it 'leaves every other profile write alone' do
      patch '/api/v3/store/customers/me', headers: bearer_headers, params: { nickname: '小二' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.nickname).to eq('小二')
    end
  end

  describe 'closing the account' do
    # An account created through WeChat: no password to type, so the phone it
    # signs in with is the proof it does have.
    let(:customer) { create(:customer, phone: phone) }
    let(:passwordless_headers) do
      api_key_headers.merge(
        'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(customer)}"
      )
    end

    before { customer.update_column(:password_digest, nil) }

    def close(headers: passwordless_headers, **params)
      post '/api/v3/store/customers/me/data_requests', headers: headers, params: { kind: 'erasure' }.merge(params)
    end

    # A WeChat account has no password to type, and the phone it signs in with
    # is the proof it does have.
    it 'accepts a code sent to the account’s own number' do
      issue_code(value: '123456')

      close(code: '123456')

      expect(response).to have_http_status(:accepted)
      expect(Spree::DataRequest.last.kind).to eq('erasure')
    end

    it 'refuses without one' do
      close

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::DataRequest.count).to eq(0)
    end

    it 'refuses a code that does not match' do
      issue_code(value: '123456')

      close(code: '999999')

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::DataRequest.count).to eq(0)
    end

    # The service answers "no number is no change" for a write, which is right
    # there and would be a way past this bar here: not even a session holder
    # erases an account that can prove nothing.
    it 'refuses an account that has neither a password nor a number' do
      customer.update_column(:phone, nil)

      close

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::DataRequest.count).to eq(0)
    end
  end
end
