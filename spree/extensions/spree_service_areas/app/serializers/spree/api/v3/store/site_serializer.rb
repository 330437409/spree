module Spree
  module Api
    module V3
      module Store
        # The site a request belongs to.
        #
        # It extends the seller profile rather than repeating it — what a
        # customer sees about a seller is one answer, whichever route asks — and
        # adds what the client holds on its global site object: who operates the
        # shop, and whether it sells memberships.
        class SiteSerializer < V3::SellerSerializer
          typelize site_svip: :boolean

          # The site's own switch, not the customer's entitlement: a membership
          # belongs to the customer, and this says whether this site sells one.
          # More than twenty screens read it off the record they already hold.
          attribute :site_svip do |seller|
            seller.site_svip?
          end

          attribute :operator do |seller|
            SiteOperatorSerializer.new(seller, params: params).to_h
          end
        end
      end
    end
  end
end
