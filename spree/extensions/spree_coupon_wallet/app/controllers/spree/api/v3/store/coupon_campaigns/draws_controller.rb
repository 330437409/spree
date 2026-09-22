module Spree
  module Api
    module V3
      module Store
        module CouponCampaigns
          # One draw against a campaign.
          #
          # What it creates is the coupon the draw answered with, so the
          # response is a holding like the wallet's own rows and the client
          # needs no second read to show what it won.
          class DrawsController < ResourceController
            prepend_before_action :require_authentication!
            before_action :set_campaign

            protected

            def model_class
              Spree::CouponHolding
            end

            def serializer_class
              Spree::Api::V3::Store::CouponHoldingSerializer
            end

            # The draw is the workflow: the campaign decides whether this
            # customer may take a coupon, the service writes the grant and the
            # holding, and the base class keeps the rendering.
            def create_workflow
              Spree::Coupons::Draw
            end

            def create_workflow_arguments
              { campaign: @campaign, customer: current_user, store: current_store }
            end

            private

            # A campaign of another store is not one this shopper may draw
            # from, and 404 is how v3 says so.
            def set_campaign
              @campaign = Spree::CouponCampaign.for_store(current_store).
                          find_by_prefix_id!(params[:coupon_campaign_id])
            end
          end
        end
      end
    end
  end
end
