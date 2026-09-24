module Spree
  module Api
    module V3
      # One thing worth telling a customer before they buy a term.
      #
      # Deliberately not a `BaseSerializer`: a check is computed from the terms
      # the customer already holds rather than stored, so it has no id, no
      # timestamps and nothing to write.
      class MembershipPurchaseCheckSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize kind: [:string, enum: Spree::MembershipKinds::Vip::CHECK_KINDS],
                 tier_name: [:string, nullable: true],
                 held_until: [:string, nullable: true]

        attribute(:kind) { |check| check['kind'] }
        attribute(:tier_name) { |check| check['tier_name'] }
        # One instant, not two: the held term's end is the bought term's start,
        # and the client renders it on both sides of the sentence.
        attribute(:held_until) { |check| check['held_until']&.iso8601 }
      end
    end
  end
end
