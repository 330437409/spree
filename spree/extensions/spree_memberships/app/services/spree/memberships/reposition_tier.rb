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

        wrote = false

        # The ladder is read inside the transaction and every rung of it is
        # held until the move is written: two operators dragging at the same
        # moment would otherwise each settle the ladder from their own snapshot
        # and leave two rungs sharing a rank.
        Spree::MembershipTierSetting.transaction do
          rungs = Spree::MembershipTierSetting.for_store(store).ordered.lock.to_a
          moved = rungs.find { |rung| rung.id == tier_setting.id }
          next if moved.nil?

          moved_to_position(rungs - [moved], moved, position).each_with_index do |rung, index|
            rank = index + 1
            rung.update_column(:rank, rank) unless rung.rank == rank
          end

          wrote = true
        end

        # A tier that is not on the ladder it asked to move within — retired
        # between the read and the write, or pointed at another store.
        return failure(tier_setting, :tier_unknown) unless wrote

        success(tier_setting)
      end

      private

      # The ladder with the moved tier dropped at the position it was given:
      # placed among the rungs rather than read back from the table, so it takes
      # the position the operator dropped it at whatever its rank was before.
      #
      # @return [Array<Spree::MembershipTierSetting>]
      def moved_to_position(other_rungs, moved, position)
        other_rungs.insert([position - 1, other_rungs.length].min, moved)
      end
    end
  end
end
