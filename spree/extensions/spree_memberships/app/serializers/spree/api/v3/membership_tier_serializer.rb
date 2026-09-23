module Spree
  module Api
    module V3
      # One rung of the ladder: what it is called, what qualifies for it, and
      # how many rights it carries.
      #
      # The name is the group's own and the rank is the server's number — the
      # client neither maps a key nor derives an order, so adding, renaming or
      # renumbering a tier costs no client release.
      class MembershipTierSerializer < BaseSerializer
        typelize name: :string, rank: :number, threshold: 'string | null',
                 validity_days: 'number | null', rights_total: :number

        attribute(:name) { |tier| tier.name }
        attribute(:rank) { |tier| tier.rank }
        attribute(:threshold) { |tier| decimal_string(tier.threshold) }
        attribute(:validity_days) { |tier| tier.validity_days }
        attribute(:rights_total) { |tier| Spree::MembershipRight.where(customer_group_id: tier.customer_group_id).count }
      end
  end
end
end
