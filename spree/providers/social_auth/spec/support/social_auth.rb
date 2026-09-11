module SocialAuthSpecHelpers
  WECHAT_TOKEN_PATTERN = %r{\Ahttps://api\.weixin\.qq\.com/sns/oauth2/access_token}.freeze
  WECHAT_PROFILE_PATTERN = %r{\Ahttps://api\.weixin\.qq\.com/sns/userinfo}.freeze
  DOUYIN_TOKEN_PATTERN = %r{\Ahttps://open\.douyin\.com/oauth/access_token/}.freeze
  DOUYIN_PROFILE_PATTERN = %r{\Ahttps://open\.douyin\.com/oauth/userinfo/}.freeze
  GOOGLE_TOKEN_PATTERN = %r{\Ahttps://oauth2\.googleapis\.com/token}.freeze
  GOOGLE_PROFILE_PATTERN = %r{\Ahttps://openidconnect\.googleapis\.com/v1/userinfo}.freeze

  JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze

  # @return [Spree::Integration]
  def create_social_integration(store: nil, integration_class: SpreeSocialAuth::Integrations::WeChat,
                               client_id: 'wx_appid', client_secret: 'wx_secret',
                               redirect_uri: 'https://shop.example.com/account/callback/wechat', active: true)
    integration = integration_class.new(store: store || @default_store, active: active)
    integration.preferred_client_id = client_id
    integration.preferred_client_secret = client_secret
    integration.preferred_redirect_uri = redirect_uri
    integration.save!
    integration
  end

  # Stubs both halves of a WeChat exchange with a successful answer.
  def stub_wechat_exchange(token: {}, profile: {})
    stub_request(:get, WECHAT_TOKEN_PATTERN).
      to_return(
        status: 200,
        headers: JSON_HEADERS,
        body: {
          access_token: 'access-token-1',
          refresh_token: 'refresh-token-1',
          expires_in: 7200,
          openid: 'openid-1'
        }.merge(token).to_json
      )

    stub_request(:get, WECHAT_PROFILE_PATTERN).
      to_return(
        status: 200,
        headers: JSON_HEADERS,
        body: {
          openid: 'openid-1',
          nickname: 'Ada',
          headimgurl: 'https://wx.example.com/ada.jpg'
        }.merge(profile).to_json
      )
  end

  # WeChat answers failures with HTTP 200 and an error code in the body.
  def stub_wechat_token_error(code:, message: 'something went wrong')
    stub_request(:get, WECHAT_TOKEN_PATTERN).
      to_return(status: 200, headers: JSON_HEADERS, body: { errcode: code, errmsg: message }.to_json)
  end

  # Douyin wraps a successful exchange in `data`, and its two endpoints carry the
  # error code in different places.
  def stub_douyin_exchange(token: {}, profile: {})
    token_data = {
      access_token: 'dy-access-token-1',
      refresh_token: 'dy-refresh-token-1',
      expires_in: 1_296_000,
      open_id: 'open-id-1',
      error_code: 0
    }.merge(token)

    profile_data = {
      open_id: 'open-id-1',
      nickname: 'Ada',
      avatar: 'https://dy.example.com/ada.jpg'
    }.merge(profile)

    stub_request(:post, DOUYIN_TOKEN_PATTERN).
      to_return(status: 200, headers: JSON_HEADERS, body: { data: token_data, message: 'success' }.to_json)

    stub_request(:post, DOUYIN_PROFILE_PATTERN).
      to_return(status: 200, headers: JSON_HEADERS, body: { data: profile_data, err_no: 0, err_msg: '' }.to_json)
  end

  def stub_douyin_token_error(code:, message: 'something went wrong')
    stub_request(:post, DOUYIN_TOKEN_PATTERN).
      to_return(
        status: 200,
        headers: JSON_HEADERS,
        body: { data: { error_code: code, description: message }, message: message }.to_json
      )
  end

  def stub_douyin_profile_error(code:, message: 'something went wrong')
    stub_request(:post, DOUYIN_PROFILE_PATTERN).
      to_return(status: 200, headers: JSON_HEADERS, body: { data: {}, err_no: code, err_msg: message }.to_json)
  end

  # Google answers with real statuses and a standard claims document.
  def stub_google_exchange(token: {}, profile: {})
    token_data = {
      access_token: 'google-access-token-1',
      expires_in: 3600,
      token_type: 'Bearer'
    }.merge(token)

    claims = {
      sub: 'google-subject-1',
      email: 'ada@example.com',
      email_verified: true,
      name: 'Ada Lovelace',
      given_name: 'Ada',
      family_name: 'Lovelace',
      picture: 'https://lh3.googleusercontent.com/ada.jpg'
    }.merge(profile)

    stub_request(:post, GOOGLE_TOKEN_PATTERN).
      to_return(status: 200, headers: JSON_HEADERS, body: token_data.to_json)

    stub_request(:get, GOOGLE_PROFILE_PATTERN).
      to_return(status: 200, headers: JSON_HEADERS, body: claims.to_json)
  end

  def stub_google_token_error(status: 400, error: 'invalid_grant', description: 'Bad Request')
    stub_request(:post, GOOGLE_TOKEN_PATTERN).
      to_return(status: status, headers: JSON_HEADERS, body: { error: error, error_description: description }.to_json)
  end
end
