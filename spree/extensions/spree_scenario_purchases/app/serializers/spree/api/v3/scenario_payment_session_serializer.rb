module Spree
  module Api
    module V3
      # The session a purchase is paid through: what the gateway handed back,
      # which is what the client passes on to WeChat, and when the attempt
      # lapses.
      #
      # Deliberately not a `BaseSerializer`, and deliberately not inheriting
      # the session serializer the cart's own endpoint uses: what a client
      # needs here is the launch parameters the gateway handed back and when
      # the attempt lapses, where that one publishes the payment machinery's
      # own identifiers and totals.
      class ScenarioPaymentSessionSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize external_id: :string, status: :string, expires_at: 'string | null',
                 external_data: 'Record<string, unknown> | null'

        attributes :external_id, :status

        attribute(:expires_at) { |session| session.expires_at&.iso8601 }
        attribute(:external_data) { |session| session.external_data }
      end
    end
  end
end
