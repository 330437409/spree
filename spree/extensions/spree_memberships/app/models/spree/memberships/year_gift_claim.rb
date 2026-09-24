module Spree
  module Memberships
    # The kind of grant an annual gift's claim is: one member taking one coupon
    # of one tier's gift, in one year of the store's own calendar.
    #
    # Those four are the whole key, so a claim is idempotent by what it is — a
    # request retried, or a member tapping twice, records nothing the second
    # time and is answered the claim the first call wrote — and the year in the
    # key is why nothing has to be reset when the year turns: the next year is a
    # different key with no job to run
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    #
    # The key names the **tier**, not the right row, because the allowance is
    # the tier's: an operator retiring a gift right and writing its replacement
    # must not hand every member of that tier a second allowance in the same
    # year, and a right row is the thing an operator replaces.
    #
    # The row is a record rather than a debt — the coupon it handed over is the
    # wallet's own row — and it is consumed as soon as it is written, so what a
    # reader needs back out of it is which coupon it was and which right it came
    # from. Both ride in the row's metadata rather than being taken apart from
    # the key.
    class YearGiftClaim < Spree::Grants::Kind
      def self.api_type
        'year_gift_claim'
      end

      # A claim is not owed and then paid: it is the record that the gift was
      # handed over, so there is nothing on the row a later event flips.
      #
      # @return [Boolean]
      def self.expires?
        false
      end

      # @param context [Hash] `:customer`, `:tier`, `:promotion` and `:year`
      # @return [String]
      def self.idempotency_key_for(context)
        "year_gift:customer:#{context[:customer].id}:tier:#{context[:tier].id}:" \
          "#{context[:year]}:promotion:#{context[:promotion].id}"
      end
    end
  end
end
