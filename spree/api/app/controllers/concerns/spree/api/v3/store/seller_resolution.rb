module Spree
  module Api
    module V3
      module Store
        # Resolves the seller a storefront request is scoped to and writes it
        # into +Spree::Current.seller+, so a catalogue read, a price and a
        # delivery area are answered for the site the customer is shopping at.
        #
        # The header is the Seller branch's own +X-Spree-Seller-Id+
        # (+SellerContext+), reused rather than renamed — the mini program
        # sends its +siteId+ on every request and maps it onto this header, so
        # the wire has one name for one fact.
        #
        # Resolution is narrower than +ChannelResolution+ beside it, and both
        # differences are deliberate:
        #
        # 1. **There is no fallback.** An absent header leaves the seller unset
        #    rather than scoping the request to a default seller; a price or an
        #    allocation answered for the wrong seller is the failure this
        #    exists to prevent. A read that needs a seller asks for one and says
        #    what it does when there is none.
        # 2. **An unresolvable header is refused** (404) rather than ignored, so
        #    a stale +siteId+ surfaces instead of quietly serving the store-wide
        #    catalogue.
        module SellerResolution
          extend ActiveSupport::Concern

          SELLER_HEADER = Spree::Api::V3::Seller::SellerContext::SELLER_HEADER

          included do
            before_action :set_current_seller
          end

          # The seller this request resolved, or nil when it named none.
          #
          # @return [Spree::Seller, nil]
          def current_seller
            @current_seller ||= seller_from_header
          end

          private

          def set_current_seller
            return if request.headers[SELLER_HEADER].blank?

            if current_seller.nil?
              render_error(
                code: ErrorHandler::ERROR_CODES[:seller_not_found],
                message: Spree.t('api.errors.seller_not_found', default: 'The requested site does not exist in this store'),
                status: :not_found
              )
            else
              Spree::Current.seller = current_seller
            end
          end

          # Scoped to the current store, so an id belonging to another tenant
          # resolves nothing — the cheapest defence against reading a foreign
          # site's catalogue.
          def seller_from_header
            value = request.headers[SELLER_HEADER].presence
            return nil if value.blank?
            return nil unless current_store

            scope = current_store.sellers
            # The opaque prefixed ID the API hands out, or the public slug a
            # storefront links with — mirrors how the channel concern accepts
            # either its code or its prefixed ID.
            if Spree::PrefixedId.prefixed_id?(value)
              scope.find_by_prefix_id(value)
            else
              scope.find_by(slug: value)
            end
          end
        end
      end
    end
  end
end
