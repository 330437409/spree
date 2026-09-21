require 'spec_helper'

RSpec.describe 'POST /api/v3/store/verification_checks', type: :request do
  include_context 'API v3 Store'

  let(:phone) { '13800138000' }

  def check_code(**params)
    post '/api/v3/store/verification_checks', headers: api_key_headers,
         params: { phone: phone, code: '123456' }.merge(params)
  end

  def issue_code(purpose: 'account', value: '123456', **attrs)
    create(:verification_code, store: store, phone: phone, purpose: purpose, code: value, **attrs)
  end

  it 'accepts the code that was sent' do
    record = issue_code

    check_code

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['phone']).to eq(phone)
    expect(response.parsed_body['verified_at']).to be_present
    expect(response.parsed_body['expires_at']).to be_present
    expect(record.reload.consumed_at).to be_nil
  end

  it 'answers a guest, because resetting a password happens before a session' do
    issue_code

    check_code

    expect(response).to have_http_status(:ok)
  end

  it 'refuses a code that does not match' do
    issue_code

    check_code(code: '999999')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['code']).to eq('verification_code_invalid')
  end

  it 'refuses a code that has expired, and says which it is' do
    issue_code(expires_at: 1.minute.ago)

    check_code

    expect(response.parsed_body['error']['code']).to eq('verification_code_expired')
  end

  it 'refuses a number nothing was sent to' do
    check_code

    expect(response.parsed_body['error']['code']).to eq('verification_code_expired')
  end

  # One endpoint serves every flow, so a caller that does not name a family is
  # answered either way; naming one narrows it.
  it 'checks the family the caller names' do
    issue_code(purpose: 'payment')

    check_code

    expect(response).to have_http_status(:ok)

    check_code(purpose: 'account')

    expect(response.parsed_body['error']['code']).to eq('verification_code_expired')
  end

  it 'refuses without a number or a code' do
    check_code(phone: nil)

    expect(response).to have_http_status(:unprocessable_content)

    check_code(code: nil)

    expect(response).to have_http_status(:unprocessable_content)
  end
end
