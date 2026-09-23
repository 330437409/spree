module Spree
  module Api
    module V3
      # One balance: what the customer holds, how much of it is about to
      # lapse, and the two rates an operator sets — what a purchase earns,
      # and what a point is worth when it is spent.
      class PointAccountSerializer < BaseSerializer
        typelize id: 'string | null', kind: :string, balance: :number, lifetime_earned: :number,
                 expiring_total: 'number | null', expires_at: 'string | null',
                 earn_rate: 'string | null', redeem_rate: 'string | null'

        attributes :kind

        attribute(:balance) { |account| account.balance }
        attribute(:lifetime_earned) { |account| account.lifetime_earned.to_i }
        # 成长值 does not lapse, so both expiry fields are null there rather
        # than zero: "nothing expires yet" and "this balance does not expire"
        # are different statements.
        # One query for both expiry figures, and neither on a balance that
        # never lapses.
        attribute(:expiring_total) { |account| account.points? ? account.expiring_summary.first : nil }
        attribute(:expires_at) { |account| account.points? ? account.expiring_summary.last&.iso8601 : nil }
        # `decimal_string`, because BigDecimal renders 100 as "0.1e3".
        attribute(:earn_rate) { |_account| decimal_string(current_store&.preferred_points_earn_rate) }
        attribute(:redeem_rate) { |_account| decimal_string(current_store&.preferred_points_redeem_rate) }
      end
    end
  end
end
