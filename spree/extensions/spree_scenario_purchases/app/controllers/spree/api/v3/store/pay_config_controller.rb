module Spree
  module Api
    module V3
      module Store
        # What can be bought here and how it is paid for.
        #
        # Readable before sign-in: the channels are the store's own, and a guest
        # is answered `false` for the payment PIN rather than refused.
        class PayConfigController < Store::BaseController
          allow_guest_storefront_access!

          def show
            config = Spree::ScenarioOrders::PayConfig.new(store: current_store, customer: try_spree_current_user)

            render json: Spree::Api::V3::PayConfigSerializer.new(config, params: serializer_params).to_h
          end
        end
      end
    end
  end
end
