module Spree
  module Api
    module V3
      module Store
        # A read that only makes sense for a site: it is answered for the seller
        # the request was scoped to, and a request that named none is refused
        # rather than answered for an arbitrary shop — which would show one
        # shop's record to a customer standing in another's.
        module SiteScope
          extend ActiveSupport::Concern

          private

          def render_missing_site
            render_error(
              code: ErrorHandler::ERROR_CODES[:seller_not_found],
              message: 'This request did not name a site. Resolve one with GET /api/v3/store/location/resolve_seller and send it as X-Spree-Seller-Id.',
              status: :not_found
            )
          end
        end
      end
    end
  end
end
