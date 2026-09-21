module Spree
  module Api
    module V3
      # One promotion a line item could be discounted by, as the engine
      # computed it — an entry of the list a storefront's picker offers and a
      # shopper's choice has to name.
      #
      # Serializes the adjuster's candidate hash rather than a record: the
      # candidate is the engine's verdict for one line, not a promotion row, and
      # what it adds over the promotion is the amount it would take off.
      class PromotionCandidateSerializer < BaseSerializer
        typelize code: [:string, nullable: true],
                 name: [:string, nullable: true], description: [:string, nullable: true],
                 amount: :string, display_amount: :string

        # The candidate's own id is the promotion's — it is what a choice names,
        # and every other payload's id sits under this key.
        attribute :id do |candidate|
          candidate[:promotion].prefixed_id
        end

        attribute :code do |candidate|
          candidate[:code]
        end

        attribute :name do |candidate|
          candidate[:promotion].name
        end

        attribute :description do |candidate|
          candidate[:promotion].description
        end

        # The discount this candidate would write, as a positive figure — the
        # engine's own amounts are negative by definition.
        attribute :amount do |candidate|
          candidate[:amount].abs.to_s
        end

        attribute :display_amount do |candidate, params|
          currency = params&.dig(:currency) || Spree::Current.currency
          Spree::Money.new(candidate[:amount].abs, currency: currency).to_s
        end
      end
    end
  end
end
