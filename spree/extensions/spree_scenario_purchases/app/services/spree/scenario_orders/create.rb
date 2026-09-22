module Spree
  module ScenarioOrders
    # Buys something: the kind prices it, the row records what it is, and the
    # session the customer pays through is opened against it.
    #
    # The frame prices nothing itself — the kind does, from the context the
    # client sent — and it grants nothing: the entitlement arrives when the
    # session settles.
    class Create
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the scenario order
      def call(kind:, store: nil, customer: nil, channel: nil, context: {}, external_data: {})
        store ||= Spree::Current.store
        channel = channel.presence || 'wechat'
        kind_class = Spree::ScenarioOrder.kind_for(kind)
        return failure(nil, :unknown_kind) if kind_class.nil?
        return failure(nil, :not_eligible) unless kind_class.eligible?(customer)

        price = kind_class.price(context)
        return failure(nil, :not_for_sale) if price.nil? || BigDecimal(price.to_s) <= 0

        payment_method = SpreeScenarioPurchases.payment_method_for(store, channel)
        return failure(nil, :channel_unavailable) if payment_method.nil?

        buy(kind_class: kind_class, store: store, customer: customer, channel: channel,
            context: context, price: price, payment_method: payment_method,
            external_data: external_data)
      rescue Spree::Core::GatewayError => e
        # The gateway's own words are what the customer needs: it is the one
        # that knows what was wrong with the call.
        failure(nil, e.message)
      end

      private

      # @return [Spree::ServiceModule::Result] value is the scenario order
      def buy(kind_class:, store:, customer:, channel:, context:, price:, payment_method:, external_data:)
        scenario_order = nil
        result = nil

        Spree::ScenarioOrder.transaction(requires_new: true) do
          scenario_order = Spree::ScenarioOrder.create!(
            store: store,
            customer: customer,
            kind: kind_class.api_type,
            payment_channel: channel,
            amount: price,
            currency: Spree::Current.currency.presence || store.default_currency,
            payload: context
          )

          session = payment_method.create_payment_session(
            order: scenario_order, amount: price, external_data: external_data
          )

          unless session.persisted?
            result = failure(scenario_order, session.errors)
            raise ActiveRecord::Rollback
          end

          scenario_order.update!(status: 'paying')
          result = success(scenario_order.reload)
        end

        result
      end
    end
  end
end
