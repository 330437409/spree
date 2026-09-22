module Spree
  module Api
    module V3
      module Store
        # One purchase: what it is, what it cost, where it is, and the session
        # paying for it — the client goes straight from this answer to the
        # gateway.
        #
        # What the kind granted is deliberately not here: a membership's term or
        # a bundle's codes are read from the plan that owns them.
        class ScenarioOrderSerializer < BaseSerializer
          typelize kind: :string, status: :string, payment_channel: :string,
                   amount: :string, currency: :string, payload: 'Record<string, unknown> | null',
                   payment_session: 'Record<string, unknown> | null'

          attribute(:kind) { |order| order.kind }
          attribute(:status) { |order| order.status }
          attribute(:payment_channel) { |order| order.payment_channel }
          attribute(:amount) { |order| decimal_string(order.amount) }
          attribute(:currency) { |order| order.currency }
          attribute(:payload) { |order| order.payload }
          attribute(:payment_session) do |order|
            session = order.payment_session
            next if session.nil?

            Spree::Api::V3::Store::ScenarioPaymentSessionSerializer.new(session, params: params).to_h
          end
        end
      end
    end
  end
end
