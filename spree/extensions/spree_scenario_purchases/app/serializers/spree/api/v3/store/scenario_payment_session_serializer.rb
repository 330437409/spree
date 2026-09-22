module Spree
  module Api
    module V3
      module Store
        # The session a purchase is paid through: what the gateway handed back,
        # which is what the client passes on to WeChat, and when the attempt
        # lapses.
        #
        # Deliberately not a `BaseSerializer`: the session's own id and
        # timestamps belong to the payment machinery, and the client needs the
        # launch parameters rather than the row.
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
end
