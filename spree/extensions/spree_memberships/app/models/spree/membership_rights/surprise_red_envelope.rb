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
      # month the term runs. Named rather than read off the list's first entry,
      # so reordering the list cannot change what every packet does.
      DEFAULT_GRANT_TYPE = 'once'.freeze
      GRANT_TYPES = [DEFAULT_GRANT_TYPE, 'month'].freeze

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

      validate :surprise_coupons_must_be_well_formed, if: :writing_surprise_coupons?
      validate :instruction_is_text_when_written, if: :writing_surprise_coupons?

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
        Spree::Memberships::SurprisePacket.new(right: self)
      end

      # The packet's coupons, in the order the tier wrote them: each promotion
      # paired with what the tier says about it. One reading of the list, so a
      # coupon and its counts cannot come from two different entries.
      #
      # The preference is JSON the model symbolises, so an entry's keys are
      # symbols here and strings on the wire.
      #
      # @return [Array<Array(Spree::Promotion, Hash)>] a coupon whose promotion
      #   an operator has since deleted drops out rather than failing the read
      def coupon_entries
        entries = Array(preferred_surprise_coupons).map { |entry| entry.respond_to?(:to_h) ? entry.to_h : {} }
        found = promotions_for(entries.map { |entry| entry[:promotion_id] }).index_by(&:prefixed_id)

        entries.filter_map do |entry|
          promotion = found[entry[:promotion_id].to_s]
          [promotion, entry] if promotion
        end
      end

      private

      # Whether an operator is writing the packet's entries now. Read by
      # comparing them with what the row holds rather than by the attribute's
      # dirty flag: `Spree::Base` fills the declared defaults in when a row is
      # loaded, so that flag is true for the first save of *every* row — which
      # would refuse a retirement nobody asked to validate, and then wave the
      # very same write through on a second attempt.
      #
      # @return [Boolean]
      def writing_surprise_coupons?
        return true if new_record?

        Array(preferred_surprise_coupons) != stored_surprise_coupons
      end

      # @return [Array] what this row's own column holds, before the write
      def stored_surprise_coupons
        stored = preferences_in_database || {}
        Array(stored[:surprise_coupons] || stored['surprise_coupons'])
      end

      # Every entry names one promotion of this store, counts a member could
      # hold, and is listed once: a packet nothing can be handed over from, or
      # one that lists the same coupon twice with two sets of counts, is an
      # operator error refused where they write it rather than where a member
      # meets it.
      def surprise_coupons_must_be_well_formed
        entries = Array(preferred_surprise_coupons)
        return if entries.present? && coupon_entries_are_well_formed?(entries)

        errors.add(:preferences, :invalid)
      end

      def coupon_entries_are_well_formed?(entries)
        listed = entries.filter_map { |entry| coupon_entry_promotion_id(entry) }

        listed.size == entries.size && listed.uniq.size == listed.size &&
          entries.all? { |entry| coupon_entry_valid?(entry) }
      end

      # @return [String, nil] the promotion an entry names, nil when it names
      #   none — which is what makes an entry that is not a hash fail
      def coupon_entry_promotion_id(entry)
        return unless entry.respond_to?(:to_h)

        entry.to_h[:promotion_id].to_s.presence
      end

      def coupon_entry_valid?(entry)
        settings = entry.to_h
        return false unless promotion_of_this_store?(settings[:promotion_id])
        return false unless GRANT_TYPES.include?(settings[:grant_type].to_s.presence || DEFAULT_GRANT_TYPE)

        %w[self_use friend_use].all? { |facet| count_written?(settings[facet.to_sym]) }
      end

      # A coupon with no count is one nobody said how many of the member gets,
      # and reading that as none would be `to_i`'s decision rather than the
      # operator's. Both spellings a client sends are accepted: a number from
      # JSON, and the digits a form sends.
      #
      # @return [Boolean]
      def count_written?(value)
        return value >= 0 if value.is_a?(Integer)

        value.is_a?(String) && value.match?(/\A\d+\z/)
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
