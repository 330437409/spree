module Spree
  module MembershipRights
    # The tier's packet of coupons — 惊喜红包 — and the counts it hands each one
    # over in.
    #
    # What a coupon is *worth* is not configured here: it is read from the
    # promotion the coupon draws on, so an operator who changes a promotion's
    # amount does not have to remember to change a second number
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class SurpriseRedEnvelope < Spree::MembershipRight
      # How a packet hands its coupons over: once with the card, or again every
      # month the term runs.
      GRANT_TYPES = %w[once month].freeze

      # The packet's coupons, in the order the client shows them: each entry
      # names the promotion it draws on and how many copies it grants, and how
      # many of those the member may give away rather than use.
      #
      # A list rather than a hash, because a packet's coupons are read in the
      # order they are written and their quantities differ from one another.
      preference :surprise_coupons, :array, default: []
      # What the packet is, in the operator's words, for a page that has no
      # money to quote — a packet of nothing but discount coupons is not worth
      # a figure, and the client prints this instead.
      preference :surprise_other_type, :string, default: ''

      validate :surprise_coupons_must_be_well_formed, if: -> { new_record? || will_save_change_to_preferences? }
      validate :instruction_is_text_when_written, if: -> { new_record? || will_save_change_to_preferences? }

      # 惊喜红包
      def self.presents_as
        'rightsLevelSurpriseVoVos'
      end

      # The packet as the member centre and the settlement page both render it.
      #
      # @param customer [Object] the member, unused: a packet has no state of
      #   its own, which is why the same payload answers a tier nobody holds
      # @param store [Spree::Store]
      # @return [Spree::Memberships::SurprisePacket]
      def member_payload(customer:, store:)
        Spree::Memberships::SurprisePacket.new(right: self, store: store)
      end

      # The promotions this packet draws on, in the order it lists them, read in
      # one query. A promotion an operator has since deleted drops out rather
      # than failing the read — the same tolerance the annual gift's list has.
      #
      # @return [Array<Spree::Promotion>]
      def coupon_promotions
        ids = Array(preferred_surprise_coupons).filter_map do |entry|
          next unless entry.respond_to?(:to_h)

          Spree::Promotion.decode_prefixed_id(entry.to_h[:promotion_id].to_s)
        end.uniq
        return [] if ids.empty?

        by_id = Spree::Promotion.where(id: ids).index_by { |promotion| promotion.id.to_s }
        ids.filter_map { |id| by_id[id.to_s] }
      end

      # What the packet says about one coupon: the counts it is handed over in
      # and its cadence. The preference is JSON the model symbolises, so its keys
      # are symbols here and strings on the wire.
      #
      # @param promotion [Spree::Promotion]
      # @return [Hash] empty when the packet says nothing, which is what a
      #   coupon listed without settings reads as
      def coupon_settings(promotion)
        entry = Array(preferred_surprise_coupons).detect do |candidate|
          candidate.respond_to?(:to_h) && candidate.to_h[:promotion_id].to_s == promotion.prefixed_id
        end

        entry ? entry.to_h : {}
      end

      private

      # Every entry names a promotion of this store and counts a member could
      # hold: a packet nothing can be handed over from is an operator error, and
      # it is refused where they write it rather than where a member meets it.
      def surprise_coupons_must_be_well_formed
        entries = Array(preferred_surprise_coupons)
        return if entries.present? && entries.all? { |entry| coupon_entry_valid?(entry) }

        errors.add(:preferences, :invalid)
      end

      def coupon_entry_valid?(entry)
        return false unless entry.respond_to?(:to_h)

        settings = entry.to_h
        return false unless promotion_of_this_store?(settings[:promotion_id])
        return false unless GRANT_TYPES.include?(settings[:grant_type].to_s.presence || 'once')

        %w[self_use friend_use].all? { |facet| settings[facet.to_sym].to_i >= 0 }
      end

      # The sentence beside a coupon is copy, so it is text or it is absent —
      # never the object a client sent by mistake.
      def instruction_is_text_when_written
        entries = Array(preferred_surprise_coupons)
        return if entries.all? { |entry| !entry.respond_to?(:to_h) || entry.to_h[:instruction].nil? || entry.to_h[:instruction].is_a?(String) }

        errors.add(:preferences, :invalid)
      end
    end
  end
end
