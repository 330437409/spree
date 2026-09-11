require 'spec_helper'

RSpec.describe SpreeSocialAuth::Client do
  subject(:client) { described_class.new }

  it 'parses a JSON body' do
    stub_request(:get, 'https://api.weixin.qq.com/sns/userinfo').to_return(status: 200, body: '{"openid":"openid-1"}')

    expect(client.get('https://api.weixin.qq.com/sns/userinfo', {})).to eq('openid' => 'openid-1')
  end

  it 'sends the parameters it was given' do
    stub = stub_request(:get, 'https://api.weixin.qq.com/sns/oauth2/access_token').
           with(query: { appid: 'wx_appid', code: 'auth-code' }).
           to_return(status: 200, body: '{"openid":"openid-1"}')

    client.get('https://api.weixin.qq.com/sns/oauth2/access_token', { appid: 'wx_appid', code: 'auth-code' })

    expect(stub).to have_been_requested
  end

  it 'posts a form body when a provider needs one' do
    stub = stub_request(:post, 'https://open.douyin.com/oauth/access_token/').
           with(body: { client_key: 'key', code: 'auth-code' }).
           to_return(status: 200, body: '{"data":{}}')

    client.post('https://open.douyin.com/oauth/access_token/', { client_key: 'key', code: 'auth-code' })

    expect(stub).to have_been_requested
  end

  it 'turns a timeout into a connection error' do
    stub_request(:get, 'https://api.weixin.qq.com/sns/userinfo').to_timeout

    expect { client.get('https://api.weixin.qq.com/sns/userinfo', {}) }.
      to raise_error(SpreeSocialAuth::ConnectionError, /could not be reached/)
  end

  # Providers that refuse with a real status (Google does) must not be read as a
  # success — the flow would carry on with an empty token.
  it 'raises on a refusal sent with a real status, naming the provider reason' do
    stub_request(:post, 'https://oauth2.googleapis.com/token').
      to_return(status: 400, headers: SocialAuthSpecHelpers::JSON_HEADERS, body: { error: 'invalid_grant', error_description: 'Bad Request' }.to_json)

    expect { client.post('https://oauth2.googleapis.com/token', {}) }.
      to raise_error(SpreeSocialAuth::ApiError, /HTTP 400: invalid_grant: Bad Request/)
  end

  it 'refuses a body that is not JSON' do
    stub_request(:get, 'https://api.weixin.qq.com/sns/userinfo').to_return(status: 200, body: '<html>nope</html>')

    expect { client.get('https://api.weixin.qq.com/sns/userinfo', {}) }.
      to raise_error(SpreeSocialAuth::ConnectionError, /not JSON/)
  end
end
