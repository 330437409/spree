module Spree
  module Memberships
    # Tells the seller ledger what the platform funded on this order.
    #
    # Contributes to `seller_transfers.create.funded_discounts`, so the row and
    # the arithmetic that turns a discount into what the seller is owed stay
    # core's, and this answers only *what* the platform promised: the member
    # price, read off the order the workflow hands it.
    #
    # Nothing is contributed for a customer holding no tier, or when the member
    # price reduced nothing — the common case by far, and one query.
    class FundMemberDiscount
      # @param workflow [Spree::SellerTransfers::Create] the running workflow
      # @return [Hash] the contribution, or nothing when the platform funded nothing
      def call(workflow)
        order = workflow.order
        tier = Spree::MembershipTierSetting.for_store(order.store).for_customer(order.customer)
        return {} if tier.nil?

        result = Spree::Memberships::MemberDiscount.call(order: order, tier: tier)
        return {} if result.failure? || result.value.empty?

        { discounts: result.value, metadata: metadata_for(tier) }
      end

      private

      # What an operator reconciling the ledger needs to answer "why was this
      # seller credited": the promise, the tier that carried it, and the price
      # it stood for.
      def metadata_for(tier)
        {
          'funded_by' => 'member_price',
          'membership_tier' => tier.name,
          'membership_tier_setting_id' => tier.id,
          'member_discount_percentage' => tier.member_discount_percentage.to_s
        }
      end
    end
  end
end
