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
      def tier_groups(customer)
        Spree::CustomerGroup.where(id: customer.customer_groups.select(:id)).
          where(id: Spree::MembershipTierSetting.select(:customer_group_id))
      end
    end
  end
end
