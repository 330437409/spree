module Spree
  module Api
    module V3
      module Store
        # The member centre: the customer's own rung, the sections its rights
        # fall into, and how many rights that rung carries.
        #
        # The sections are whatever the registry produces — a kind that declares
        # a panel adds a key here with no change to this file — and each entry
        # says which tier carries it and whether that tier is the customer's.
        class MemberCentreSerializer < BaseSerializer
          typelize tier: 'Record<string, unknown> | null', rights_total: :number,
                   sections: 'Record<string, Array<Record<string, unknown>>>'

          attribute(:tier) do |centre|
            next if centre.tier.nil?

            Spree::Api::V3::Store::MembershipTierSerializer.new(centre.tier, params: params).to_h
          end

          attribute(:rights_total) { |centre| centre.rights_total }

          attribute(:sections) do |centre|
            centre.sections.transform_values do |rights|
              rights.map do |right|
                Spree::Api::V3::Store::MembershipRightSerializer.new(right, params: params).
                  to_h.merge('is_have' => centre.holds?(right))
              end
            end
          end
        end
      end
    end
  end
end
