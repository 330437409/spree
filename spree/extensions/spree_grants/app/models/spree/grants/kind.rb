module Spree
  module Grants
    # What every kind of grant answers, and the whole of the contract: how it
    # builds its own idempotency key, what consuming means, and whether its
    # grants expire at all.
    #
    # A kind is a class the plan that owns the thing registers —
    # `Spree.grant_kinds << SpreeMembership::GrantKinds::Right` — and the row
    # it writes is a `Spree::Grant` whose `kind` column names it by
    # `api_type`. Deliberately three methods: a grant's amount, its balance
    # and its allocations belong to the plan that owns the thing owed, in its
    # own side table keyed to the grant
    # (docs/plans/6.1-grant-and-benefit-primitive.md).
    class Kind
      # The name the row stores and a picker reads. Derived from the class the
      # way {Spree::Base.api_type} derives it, so a kind that renames its class
      # pins this rather than changing what every stored row means.
      #
      # @return [String]
      def self.api_type
        to_s.demodulize.underscore
      end

      # The key that makes granting idempotent, built by the kind because only
      # the kind knows what makes its grants one grant: a membership gift is
      # unique per right and period, a coupon per code, a points lot per
      # source. `Spree::Grants.grant!` records a debt under this key once and
      # answers the existing row every time after.
      #
      # @param context [Object] whatever this kind needs to build the key
      # @return [String]
      def self.idempotency_key_for(context)
        raise NotImplementedError
      end

      # Whether taking the thing is a thing at all. A one-shot kind is
      # consumed once, a partial kind is consumed through its owner's service
      # until what it holds runs out, and a welfare card's grant is neither:
      # the card it points at already carries what it is worth.
      #
      # @return [Boolean]
      def self.consumable?
        true
      end

      # Whether this kind's grants carry an expiry. A kind that answers false
      # has no use for the column, and the row refuses a date on it.
      #
      # @return [Boolean]
      def self.expires?
        true
      end

      # Consumes the grant, or refuses. The default is the one-shot kind: stamp
      # the row. A kind that consumes in part overrides this and calls the
      # service that owns the thing — the primitive records consumption, it
      # never performs it.
      #
      # A kind that overrides it answers with {.accept} or {.refuse}.
      #
      # @param grant [Spree::Grant]
      # @return [Spree::ServiceModule::Result]
      def self.consume!(grant)
        return refuse(grant, :not_consumable) unless consumable?
        return refuse(grant, :not_usable) unless grant.consume!

        accept(grant.reload)
      end

      # The answer a kind gives when it has consumed the grant itself, so a
      # kind's own service and the default one speak the same shape.
      #
      # @param grant [Spree::Grant]
      # @return [Spree::ServiceModule::Result]
      def self.accept(grant)
        Spree::ServiceModule::Result.new(true, grant)
      end

      # …and when it will not: the reason is what the caller is told.
      #
      # @param grant [Spree::Grant]
      # @param reason [Symbol, String]
      # @return [Spree::ServiceModule::Result]
      def self.refuse(grant, reason)
        Spree::ServiceModule::Result.new(false, grant, Spree::ServiceModule::ResultError.new(reason))
      end
    end
  end
end
