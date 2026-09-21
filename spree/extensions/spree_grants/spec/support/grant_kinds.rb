# Three kinds, one per shape the contract has to carry: a one-shot gift, a
# lot consumed through its owner, and a card that is neither consumable nor
# expiring. They stand in for the kinds the consumer gems will register.
module SpecGrantKinds
  class Gift < Spree::Grants::Kind
    def self.api_type
      'spec_gift'
    end

    def self.idempotency_key_for(context)
      "gift:#{context}"
    end
  end

  class Lot < Spree::Grants::Kind
    def self.api_type
      'spec_lot'
    end

    def self.idempotency_key_for(context)
      "lot:#{context}"
    end

    # Consumed in part through the plan that owns the thing, which is what the
    # primitive delegates rather than performing.
    def self.consume!(grant)
      grant.update!(status: 'consumed', metadata: grant.metadata.merge('through' => 'the owner'))

      accept(grant)
    end
  end

  class Card < Spree::Grants::Kind
    def self.api_type
      'spec_card'
    end

    def self.idempotency_key_for(context)
      "card:#{context}"
    end

    def self.consumable?
      false
    end

    def self.expires?
      false
    end
  end
end

# A kind of the shape a consumer's gem defines: a named class in its own
# namespace, whose name is what the row will store.
module SpreeMembership
  module GrantKinds
    class Birthday < Spree::Grants::Kind
    end
  end
end

RSpec.configure do |config|
  config.around(:each) do |example|
    kept = Spree.grant_kinds.dup
    Spree.grant_kinds.concat([SpecGrantKinds::Gift, SpecGrantKinds::Lot, SpecGrantKinds::Card])
    example.run
  ensure
    Spree.grant_kinds.replace(kept)
  end
end
