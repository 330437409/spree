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
        # Sized rather than counted: a ladder reader preloads the rights, and a
        # rung whose rights nobody loaded answers with the count query `size`
        # falls back to. One number per rung, and a ladder is one read.
        attribute(:rights_total) { |tier| tier.rights.size }
      end
    end
  end
end
