module Spree
  module Coupons
    # One draw against a campaign: the customer asks, the campaign answers, and
    # a coupon arrives in their wallet.
    #
    # Distinct from `Spree::CouponCampaigns::Draw`, which is the campaign
    # *type* that hands coupons out to anyone inside the window — this is the
    # action, whatever kind the campaign is.
    class Draw
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the holding
      def call(campaign:, customer:, store: nil)
        return failure(nil, :coupon_not_running) unless campaign.running?
        return failure(nil, :coupon_not_eligible) unless campaign.eligible_for?(customer)
        return failure(nil, :coupon_limit_reached) if taken_by(customer, campaign) >= campaign.preferred_limit_per_customer.to_i

        Spree::Coupons::Issue.call(
          promotion: campaign.promotion,
          campaign: campaign,
          customer: customer,
          source: 'draw',
          store: store || campaign.store,
          expires_at: campaign.expiry_for_grant,
          idempotency_key: key_for(campaign, customer)
        )
      end

      private

      # The key counts what the customer has already taken, deleted rows
      # included: a draw somebody tapped twice builds the same key and is
      # answered with the first coupon, while the next draw builds the next
      # key. Counting deleted rows too keeps the sequence from handing a key
      # back to a debt that was already recorded.
      #
      # @return [String]
      def key_for(campaign, customer)
        "coupon_draw:#{campaign.id}:#{customer.id}:#{taken_by(customer, campaign, deleted: true) + 1}"
      end

      # How many coupons this customer has taken from this campaign.
      #
      # @return [Integer]
      def taken_by(customer, campaign, deleted: false)
        scope = deleted ? Spree::CouponHolding.with_deleted : Spree::CouponHolding
        scope.for_customer(customer).for_campaign(campaign).count
      end
    end
  end
end
