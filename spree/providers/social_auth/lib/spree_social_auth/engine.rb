require 'rails/engine'

module SpreeSocialAuth
  class Engine < Rails::Engine
    engine_name 'spree_social_auth'

    # Gem name and module disagree on word boundaries (spree_social_auth →
    # SpreeSocialAuth), and WeChat is not what Zeitwerk would guess from
    # `wechat`.
    initializer 'spree_social_auth.inflections', before: :set_autoload_paths do
      Rails.autoloaders.each do |autoloader|
        autoloader.inflector.inflect(
          'spree_social_auth' => 'SpreeSocialAuth',
          'wechat' => 'WeChat'
        )
      end
    end

    # Core assigns the authentication registry in its own after_initialize, so
    # appending has to happen in a later one — engine callbacks run in load
    # order. Each provider is one Integration (its per-store credentials) and one
    # strategy class; registering both is the whole wiring.
    config.after_initialize do
      [
        SpreeSocialAuth::Strategies::WeChat,
        SpreeSocialAuth::Strategies::Douyin,
        SpreeSocialAuth::Strategies::Google
      ].each do |strategy|
        provider = strategy.provider

        Spree.integrations << provider.integration_class.name
        Spree.store_authentication_strategies.add(provider.key, provider)
      end
    end
  end
end
