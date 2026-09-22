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
        return @tier if defined?(@tier)

        @tier = Spree::MembershipTierSetting.for_store(store).for_customer(customer)
      end

      # Every live right of this store's tiers, in the ladder's own order: the
      # tiers' ranks, then each tier's own positions.
      #
      # Read once and held: a response groups these and counts them, and both
      # would otherwise ask the same question again.
      #
      # @return [Array<Spree::MembershipRight>]
      def rights
        @rights ||= rights_relation.to_a
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

      # @return [ActiveRecord::Relation]
      def rights_relation
        Spree::MembershipRight.
          where(customer_group_id: Spree::MembershipTierSetting.for_store(store).select(:customer_group_id)).
          joins(:tier_setting).
          order(Spree::MembershipTierSetting.arel_table[:rank].asc, :position, :id)
      end
    end
  end
end
