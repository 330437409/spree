module Spree
  module Api
    module V3
      module Store
        # How the site is operated, as an object of its own because the client
        # reads these fields together on the page that qualifies the shop —
        # and because they describe the business behind the site rather than
        # the seller a shopper browses.
        class SiteOperatorSerializer < V3::BaseSerializer
          typelize site_name: :string, company_name: [:string, nullable: true],
                   image_url: [:string, nullable: true], business_model: [:string, nullable: true]

          attribute :site_name do |seller|
            seller.name
          end

          attribute :company_name do |seller|
            seller.legal_name
          end

          attribute :image_url do |seller|
            image_url_for(seller.logo)
          end

          attribute :business_model do |seller|
            seller.business_model
          end
        end
      end
    end
  end
end
