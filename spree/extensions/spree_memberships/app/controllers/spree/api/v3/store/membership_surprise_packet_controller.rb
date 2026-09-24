module Spree
  module Api
    module V3
      module Store
        # The packet of coupons a tier grants, asked about a tier the customer
        # has not bought yet: what the settlement page shows before the purchase.
        # The member centre reads the same payload off the right, once they hold
        # it.
        #
        # A tier that grants no packet is answered `null` rather than as an empty
        # one: a packet nobody can be handed from is refused where it is written,
        # so "this tier has none" and "this one has none yet" are one answer, and
        # the client reads it the same way it reads a tier with no banner.
        class MembershipSurprisePacketController < Store::BaseController
          prepend_before_action :require_authentication!

          def show
            packet = packet_for(tier)

            render json: packet.nil? ? nil : Spree::Api::V3::SurprisePacketSerializer.new(
              packet, params: serializer_params
            ).to_h
          end

          private

          # @return [Spree::MembershipTierSetting]
          def tier
            @tier ||= Spree::MembershipTierSetting.for_store(current_store).
                      find_by_prefix_id!(params[:tier_id])
          end

          # The kind is named because this endpoint is about what that kind
          # grants. A gem adding a second packet-bearing kind would extend this
          # and the member centre's payload lookup together — the member centre
          # renders any payload it knows a shape for, while this answers only the
          # built-in one.
          #
          # @return [Spree::Memberships::SurprisePacket, nil]
          def packet_for(tier)
            right = tier.published_rights.detect do |candidate|
              candidate.is_a?(Spree::MembershipRights::SurpriseRedEnvelope)
            end
            return if right.nil?

            right.member_payload(customer: current_user, store: current_store)
          end
        end
      end
    end
  end
end
