module Spree
  module Memberships
    # Puts a customer on a tier, and never on two.
    #
    # `Spree::Catalog.for_customer_groups` prices from any group the customer is
    # in, taking the first that yields a price — so a customer sitting on two
    # tiers is priced by whichever catalogue happens to sit lower, silently, and
    # not by their better tier. That is V-3570's shape: the code was right, the
    # setup was wrong and nothing said so.
    #
    # So the ladder has one writer. A tier change takes the customer off
    # whatever tier holds them and puts them on this one in one transaction, and
    # a card's activation, the term it starts and the sweep that ends one all
    # come through here (docs/plans/6.1-membership-tiers-and-rights.md).
    class AssignTier
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the customer
      def call(customer:, customer_group:)
        return failure(customer, :tier_unknown) unless tier?(customer_group)

        Spree::CustomerGroup.transaction(requires_new: true) do
          Spree::Memberships::UnassignTier.call(customer: customer)
          customer_group.add_customers([customer.id])
        end

        success(customer)
      end

      private

      # @return [Boolean] whether this group is a tier rather than any audience
      def tier?(customer_group)
        Spree::MembershipTierSetting.exists?(customer_group_id: customer_group&.id)
      end
    end
  end
end
