module Spree
  module Api
    module V3
      module Store
        # The one share payload: what a WeChat share card says, and where it
        # opens, for whatever kind of thing the request names
        # (docs/plans/6.1-store-api-miniprogram-gaps.md).
        #
        # It is written rather than read because composing a card may mint what
        # the card needs — an invitation's binding, a team's join link — which
        # keeps the client to one call per share.
        class SharesController < Store::BaseController
          # POST /api/v3/store/shares
          def create
            return if render_missing_target

            target = find_target
            return if performed?

            result = Spree::Shares::Compose.call(target: target, context: context_param)

            return render_not_shareable unless result.success?

            render json: serializer_class.new(result.value, params: serializer_params).to_h
          end

          private

          def serializer_class
            Spree::Api::V3::Store::ShareSerializer
          end

          def permitted_params
            params.permit(:target_type, :target_id, context: {})
          end

          # What the target's own descriptor reads — a binding to mint, a team
          # to join. Passed through untouched, because the route serves every
          # target rather than the ones this application happens to have.
          def context_param
            permitted_params[:context].to_h.symbolize_keys
          end

          # The target, resolved through the relation its type declares and
          # only that relation: an id from another store, or of a product this
          # storefront does not show, is a 404 rather than a card.
          #
          # @return [Object, nil] nil when the request was already refused
          def find_target
            resolver = Spree.shareable_targets[permitted_params[:target_type].to_s]
            return render_unknown_target if resolver.nil?

            resolver.call(current_store, current_channel, current_user).
              find_by_prefix_id!(permitted_params[:target_id])
          end

          # A request that names nothing is a request to fix: the two words are
          # what every kind of share is addressed by.
          # @return [Boolean] true when the request was refused
          def render_missing_target
            return false if permitted_params[:target_type].present? && permitted_params[:target_id].present?

            render_error(
              code: ErrorHandler::ERROR_CODES[:validation_error],
              message: Spree.t('api.errors.share_target_required'),
              status: :unprocessable_content
            )
            true
          end

          def render_unknown_target
            render_error(
              code: ErrorHandler::ERROR_CODES[:record_not_found],
              message: Spree.t('api.errors.unknown_share_target', type: permitted_params[:target_type]),
              status: :not_found
            )
          end

          def render_not_shareable
            render_error(
              code: ErrorHandler::ERROR_CODES[:validation_error],
              message: Spree.t('api.errors.not_shareable', type: permitted_params[:target_type]),
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
