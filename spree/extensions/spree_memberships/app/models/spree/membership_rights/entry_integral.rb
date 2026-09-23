module Spree
  module MembershipRights
    # Points credited the moment the member enters the tier — the `giftIntegral`
    # half of the client's 恭喜升级 bag.
    #
    # Whole points only, and the ledger refuses a zero or negative amount, so a
    # right an operator has not filled in hands over nothing rather than failing
    # an activation.
    class EntryIntegral < Spree::MembershipRight
      preference :amount, :integer, default: 0

      # The upgrade modal is the panel the client reads the bag from.
      def self.presents_as
        'levelRelationVo'
      end

      # @return [Integer, nil] nil when there is nothing to hand over
      def entry_points
        amount = preferred_amount.to_i
        amount if amount.positive?
      end
    end
  end
end
