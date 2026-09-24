module Spree
  module Api
    module V3
      # What the buy page's savings popup says about a tier: the four rows of
      # copy, the rules under them, and the monthly figure the headline quotes.
      #
      # Deliberately not a `BaseSerializer`: the payload is about a tier rather
      # than being one, so it has no id of its own to carry and nothing to
      # update.
      class MembershipSavingSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize rows: 'MembershipSavingRow[]', rules: 'string | null', month_amount: 'string | null'

        attribute(:rows) do |tier|
          tier.saving_rows.map do |row|
            Spree::Api::V3::MembershipSavingRowSerializer.new(row, params: params).to_h
          end
        end
        attribute(:rules) { |tier| tier.preferred_saving_rules.presence }
        attribute(:month_amount) { |tier| tier.saving_month_amount }
      end
    end
  end
end
