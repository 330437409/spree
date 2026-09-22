module Spree
  module ScenarioOrders
    # What `GET /pay_config` answers: the channels this store can take money in,
    # what each registered kind sells, and whether this customer has a payment
    # PIN.
    #
    # One object for two of the client's calls (`getPayConfigV2` and
    # `getPaySettingByUserId`), because they answer one question between them.
    # The kinds are listed by their own classes — the frame knows nothing about
    # what a membership costs, and asks.
    class PayConfig
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :store
      attribute :customer

      # The channels with a gateway behind them, and only those: a channel
      # named without one is a column value a client cannot pay in.
      #
      # @return [Array<Hash>]
      def channels
        SpreeScenarioPurchases::CHANNELS.filter_map do |channel, _gateway_class|
          next if SpreeScenarioPurchases.payment_method_for(store, channel).nil?

          { 'channel' => channel }
        end
      end

      # What the kinds sell. A kind that lists nothing is still named, so a
      # client can tell "this store does not sell memberships" from "this store
      # sells none right now".
      #
      # @return [Array<Hash>]
      def kinds
        Spree::ScenarioOrder.available_kinds.map do |kind_class|
          {
            'kind' => kind_class.api_type,
            'name' => kind_class.human_name,
            'eligible' => kind_class.eligible?(customer),
            'offers' => kind_class.offers
          }
        end
      end

      # Whether this customer has a payment PIN to enter. Read through the
      # verification-code gem when it is installed, and `false` without it: a
      # store that has never set one up asks for none.
      #
      # @return [Boolean]
      def payment_pin?
        return false if customer.nil? || !defined?(Spree::PaymentPin)

        Spree::PaymentPin.exists?(customer: customer, store: store)
      end
    end
  end
end
