module Spree
  module Memberships
    # The member centre's sections, as the registry produces them.
    #
    # The client reads the rights twice and the two reads disagree about
    # grouping: the rights page takes a flat list, and the member centre takes
    # the same rights grouped into named panels. The flat list is therefore the
    # model and the grouping is a projection of it — every live right of the
    # store's tiers, grouped by the panel its kind declares.
    #
    # Nothing here names a panel. A kind that declares one joins it, and a kind
    # that declares none is a right with no panel in this client, which is the
    # honest outcome: enumerating the panels server-side would make adding a kind
    # a server change again and the registry would earn nothing.
    #
    # A panel is not "my tier's rights" — the plan's own read of the client says
    # a panel is the ladder, with the customer's own rung marked. So each entry
    # carries its tier and whether the customer holds it.
    class MemberCentre
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :store
      attribute :customer

      # The tier this customer is in, or nil when they are in none.
      #
      # @return [Spree::MembershipTierSetting, nil]
      def tier
        return nil if customer.nil?

        Spree::MembershipTierSetting.for_store(store).
          where(customer_group_id: group_ids_for(customer)).
          ordered.first
      end

      # Every live right of this store's tiers, in the ladder's own order.
      #
      # The order is the tiers' ranks, then each tier's own positions — written
      # as a CASE because the rights hang from the group rather than from the
      # settings row, and a join to it would be a join to a table this model has
      # no association to.
      #
      # @return [ActiveRecord::Relation]
      def rights
        group_ids = ladder_ids
        return Spree::MembershipRight.none if group_ids.empty?

        ordering = Arel::Nodes::Case.new(Spree::MembershipRight.arel_table[:customer_group_id])
        group_ids.each_with_index { |group_id, index| ordering.when(group_id).then(index) }

        Spree::MembershipRight.where(customer_group_id: group_ids).order(ordering.asc, :position, :id)
      end

      # The rights grouped by the panel their kind declares, in the order the
      # kinds were registered in.
      #
      # @return [Hash{String => Array<Spree::MembershipRight>}]
      def sections
        rights.group_by { |right| right.class.presents_as }.except(nil)
      end

      # How many rights the customer's own tier carries. The client binds this
      # rather than counting, so it has to mean what it says.
      #
      # @return [Integer]
      def rights_total
        return 0 if tier.nil?

        rights.count { |right| right.customer_group_id == tier.customer_group_id }
      end

      # @return [Boolean] whether the customer holds the tier this right hangs on
      def holds?(right)
        tier.present? && right.customer_group_id == tier.customer_group_id
      end

      private

      # The group ids of this store's tiers, in rank order.
      #
      # @return [Array<Integer>]
      def ladder_ids
        Spree::MembershipTierSetting.for_store(store).ordered.pluck(:customer_group_id)
      end

      # @return [ActiveRecord::Relation]
      def group_ids_for(customer)
        Spree::CustomerGroupUser.
          where(user_id: customer.id, user_type: Spree.customer_class.to_s).
          select(:customer_group_id)
      end
    end
  end
end
