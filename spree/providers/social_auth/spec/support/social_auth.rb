module SocialAuthSpecHelpers
  WECHAT_TOKEN_PATTERN = %r{\Ahttps://api\.weixin\.qq\.com/sns/oauth2/access_token}.freeze
  WECHAT_PROFILE_PATTERN = %r{\Ahttps://api\.weixin\.qq\.com/sns/userinfo}.freeze

  # @return [SpreeSocialAuth::Integrations::WeChat]
  def create_social_integration(store: nil, client_id: 'wx_appid', client_secret: 'wx_secret',
                               redirect_uri: 'https://shop.example.com/account/callback/wechat', active: true)
    integration = SpreeSocialAuth::Integrations::WeChat.new(store: store || @default_store, active: active)
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
        headers: { 'Content-Type' => 'application/json' },
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
        headers: { 'Content-Type' => 'application/json' },
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
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { errcode: code, errmsg: message }.to_json
      )
  end
end
