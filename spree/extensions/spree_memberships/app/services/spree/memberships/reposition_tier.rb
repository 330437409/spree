module Spree
  module Memberships
    # Moving a rung rewrites its store's ladder.
    #
    # The ladder's order is the operator's and they arrange it by dragging it,
    # so a rank is the sequence itself rather than a number kept in step by
    # hand: a move settles the whole ladder into 1..n, and a gap or a tie left
    # behind by an earlier edit is not something to preserve
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class RepositionTier
      prepend Spree::ServiceModule::Base

      # @param tier_setting [Spree::MembershipTierSetting] the rung to move
      # @param new_position [Integer, String] the 1-indexed rung it takes; past
      #   either end the tier lands at that end
      # @return [Spree::ServiceModule::Result] value is the tier
      def call(tier_setting:, new_position:)
        store = tier_setting.store
        return failure(tier_setting, :store_missing) if store.nil?

        position = new_position.to_i
        return failure(tier_setting, :position_invalid) if position < 1

        ladder = other_rungs(store, tier_setting)
        ladder.insert([position - 1, ladder.length].min, tier_setting)

        Spree::MembershipTierSetting.transaction do
          ladder.each_with_index do |rung, index|
            rank = index + 1
            rung.update_column(:rank, rank) unless rung.rank == rank
          end
        end

        success(tier_setting)
      end

      private

      # The store's other rungs, in the order they stand. The moved tier is
      # placed among them rather than read back from the table, so the position
      # an operator dropped it at is the position it takes whatever its rank
      # was before.
      #
      # @return [Array<Spree::MembershipTierSetting>]
      def other_rungs(store, tier_setting)
        Spree::MembershipTierSetting.for_store(store).where.not(id: tier_setting.id).ordered.to_a
      end
    end
  end
end
