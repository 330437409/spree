module Spree
  module Api
    module V3
      # The member centre: the customer's own rung, the sections its rights
      # fall into, and how many rights that rung carries.
      #
      # The sections are whatever the registry produces — a kind that declares
      # a panel adds a key here with no change to this file — and each entry
      # says which tier carries it and whether that tier is the customer's.
      class MemberCentreSerializer < BaseSerializer
        typelize tier: 'Record<string, unknown> | null', rights_total: :number,
                 sections: 'Record<string, Array<Record<string, unknown>>>',
                 birthday: 'Record<string, unknown> | null'

        attribute(:tier) do |centre|
          next if centre.tier.nil?

          Spree::Api::V3::MembershipTierSerializer.new(centre.tier, params: params).to_h
        end

        attribute(:rights_total) { |centre| centre.rights_total }

        attribute(:birthday) { |centre| centre.birthday }

        # A kind that contributes something of its own — the annual gift's
        # coupons and what is left of the year's allowance, the surprise packet's
        # coupons — has it merged into its entry rather than answered by a second
        # read: the panel and the entitlement read are one payload here. Every
        # kind is asked and most answer nil, so no kind is named; what is named is
        # the payload shapes there are, and a kind answering anything else is a
        # wire shape nobody has decided — which is worth failing over rather than
        # dropping from the panel in silence.
        PAYLOADS = {
          Spree::Memberships::YearGift => ['gift', Spree::Api::V3::YearGiftSerializer].freeze,
          Spree::Memberships::SurprisePacket => ['packet', Spree::Api::V3::SurprisePacketSerializer].freeze
        }.freeze

        attribute(:sections) do |centre|
          centre.sections.transform_values do |rights|
            rights.map do |right|
              entry = Spree::Api::V3::MembershipRightSerializer.new(right, params: params).
                      to_h.merge('is_have' => centre.holds?(right))

              payload = centre.payload_for(right)
              next entry if payload.nil?

              key, serializer = PAYLOADS.fetch(payload.class) do
                raise ArgumentError, "no wire shape for #{payload.class}"
              end
              entry.merge(key => serializer.new(payload, params: params).to_h)
            end
          end
        end
      end
    end
  end
end
