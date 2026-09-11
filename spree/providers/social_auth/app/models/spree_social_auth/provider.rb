module SpreeSocialAuth
  # One provider's entry in the store authentication registry.
  #
  # The registry holds a factory rather than a bare strategy class because the
  # credentials live per store: the entry carries the provider's identity,
  # answers whether *this store* has it configured, and builds one strategy per
  # request. It deliberately memoizes nothing that comes from the store — the
  # factory outlives every request in the process, and a cached integration
  # would serve one store's credentials to another.
  class Provider
    attr_reader :key, :label, :strategy_class, :integration_class

    def initialize(key:, label:, strategy_class:, integration_class:, requires_email: false)
      @key = key.to_sym
      @label = label
      @strategy_class = strategy_class
      @integration_class = integration_class
      @requires_email = requires_email
    end

    def kind
      :redirect
    end

    # Whether the provider can answer without an email the account needs,
    # published so the storefront can warn that a registration step is coming.
    def requires_email
      @requires_email
    end

    def build(params:, request_env:, user_class: nil)
      strategy_class.new(
        params: params,
        request_env: request_env,
        user_class: user_class,
        provider: key,
        integration: integration
      )
    end

    # Only a store that has configured and activated this provider sees it.
    def available?
      integration.present?
    end

    def authorization_url(state:)
      build(params: {}, request_env: {}).authorization_url(state: state)
    end

    private

    # Read per call: Spree::Current.integrations is this request's snapshot of
    # the store's active integrations.
    def integration
      Spree::Current.integrations.find { |candidate| candidate.is_a?(integration_class) }
    end
  end
end
