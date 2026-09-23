module Spree
  module Api
    module V3
      module Store
        module Customer
          # The customer's own two balances.
          #
          # The collection is fixed — 积分 and 成长值, in that order — so the
          # read answers both even when neither has ever moved: a customer
          # whose balance is zero has a balance. The account row is written the
          # first time something moves, which keeps a read a read.
          class PointAccountsController < ResourceController
            prepend_before_action :require_authentication!

            def index
              render json: { data: Spree::PointAccount::KINDS.map { |kind| serialize_resource(account_for(kind)) } }
            end

            protected

            def model_class
              Spree::PointAccount
            end

            def serializer_class
              Spree::Api::V3::PointAccountSerializer
            end

            def scope
              super.where(store: current_store, customer: current_user)
            end

            private

            # @return [Spree::PointAccount] the customer's row for this
            #   balance, or an unsaved one that answers zero
            def account_for(kind)
              scope.find_by(kind: kind) ||
                Spree::PointAccount.new(store: current_store, customer: current_user, kind: kind)
            end
          end
        end
      end
    end
  end
end
