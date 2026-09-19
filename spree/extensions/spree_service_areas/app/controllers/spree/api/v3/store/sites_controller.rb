module Spree
  module Api
    module V3
      module Store
        # The record of the site a request belongs to.
        #
        # The client assigns this payload wholesale to its global site object
        # and every screen reads fields off that, so it is the seller's public
        # profile plus how the shop is operated and what it enables. Which site
        # it describes is the request's own scope — the `X-Spree-Seller-Id`
        # header, resolved once at the boundary — and a request that named none
        # is refused rather than answered for an arbitrary site.
        class SitesController < Store::BaseController
          include Spree::Api::V3::HttpCaching

          allow_guest_storefront_access!

          # GET /api/v3/store/site
          def show
            return render_missing_site if current_seller.nil?
            return unless cache_resource(current_seller)

            render json: serializer_class.new(current_seller, params: serializer_params).to_h
          end

          private

          # The request named no site. That is a client that skipped the lookup
          # rather than a missing record, so the message says which call settles
          # it — the alternative, falling back to a store-wide site, would serve
          # one shop's record to a customer standing in another's.
          def render_missing_site
            render_error(
              code: ErrorHandler::ERROR_CODES[:seller_not_found],
              message: 'This request did not name a site. Resolve one with GET /api/v3/store/location/resolve_seller and send it as X-Spree-Seller-Id.',
              status: :not_found
            )
          end

          def serializer_class
            Spree::Api::V3::Store::SiteSerializer
          end
        end
      end
    end
  end
end
