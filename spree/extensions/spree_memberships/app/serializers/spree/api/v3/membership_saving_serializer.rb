module Spree
  module Api
    module V3
      # What the buy page's savings popup says about a tier: the four rows of
      # copy, the rules under them, and the monthly figure the headline quotes.
      #
      # Nothing here is computed. What a member saves is their basket times this
      # tier's member price, so the operator says what it is and the read repeats
      # them — which is also why a tier nobody has written for answers blanks
      # rather than being refused.
      class MembershipSavingSerializer < BaseSerializer
        typelize rows: 'MembershipSavingRow[]', rules: 'string | null', month_amount: 'string | null'

        attribute(:rows) do |tier|
          tier.saving_rows.map do |row|
            Spree::Api::V3::MembershipSavingRowSerializer.new(row, params: params).to_h
          end
        end
        attribute(:rules) { |tier| tier.preferred_saving_rules.presence }
        attribute(:month_amount) { |tier| decimal_string(tier.preferred_saving_month_amount) }
      end
    end
  end
end
