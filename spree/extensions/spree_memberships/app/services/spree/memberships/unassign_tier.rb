module Spree
  module Memberships
    # Takes a customer off the ladder, and off nothing else.
    #
    # The other half of {AssignTier}: a term that ends leaves its tier's group,
    # because member pricing reads the group, so a lapsed member who keeps it
    # keeps the price. Only *tier* groups are touched — the wholesale audience a
    # customer also belongs to is somebody else's fact.
    class UnassignTier
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the customer
      def call(customer:)
        return failure(customer, :customer_missing) if customer.nil?

        Spree::CustomerGroup.transaction(requires_new: true) do
          tier_groups(customer).find_each { |group| group.remove_customers([customer.id]) }
        end

        success(customer)
      end

      private

      # @return [ActiveRecord::Relation] every tier group this customer is on
      #
      # Retired tiers count: a group is a tier's group while a term for it is
      # being ended, and the tier settings row is soft-deleted exactly when the
      # catalogue that prices it was switched off — which is the member this is
      # here to remove.
      def tier_groups(customer)
        Spree::CustomerGroup.where(id: customer.customer_groups.select(:id)).
          where(id: Spree::MembershipTierSetting.with_deleted.select(:customer_group_id))
      end
    end
  end
end
