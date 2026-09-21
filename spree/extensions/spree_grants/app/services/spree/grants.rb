module Spree
  # The only door to `Spree::Grant`. The row records what is owed; this module
  # is how a debt comes to exist and how it moves.
  #
  # It performs no issuance and holds no money. The plan that owns the thing —
  # a coupon, a membership card, a points lot — issues it in its own
  # transaction and passes the result in as `issued:`, and a kind that is
  # consumed in part consumes through that plan's own service. That is the
  # boundary that keeps the primitive from becoming a second ledger
  # (docs/plans/6.1-grant-and-benefit-primitive.md).
  module Grants
    # Raised when a caller names a kind nothing registered. A kind is how the
    # service knows what a grant means — and only a registered one, so a
    # shorthand no gem has claimed cannot be written into the table.
    class UnknownKind < StandardError; end

    # Records that the store owes this customer something, once.
    #
    # Idempotent by the key the kind builds: a job that runs twice records
    # nothing the second time and is answered with the row the first run
    # wrote — including a row somebody removed, because the key means the debt
    # was already recorded.
    #
    # @param kind [Class, String] the registered kind, or its `api_type`
    # @param customer [Object, nil] who is owed it; nil while it is owed to
    #   nobody yet — a drawn coupon before someone claims it
    # @param source [Object, nil] what caused it: an order, a right, a campaign
    # @param idempotency_key [String, nil] the key, when the caller built it
    #   with the kind's own {Spree::Grants::Kind.idempotency_key_for}
    # @param context [Object, nil] what the kind needs to build the key itself;
    #   ignored when `idempotency_key` is given
    # @param expires_at [Time, nil] read by the `usable` scope, never flipped
    #   by a job
    # @param issued [Object, nil] what it released, which another plan owns
    # @param granted_at [Time, nil] defaults to now
    # @param metadata [Hash, nil]
    # @param store [Spree::Store, nil] the store the debt belongs to; falls
    #   back to the current request's, which is why a job passes it
    # @return [Spree::ServiceModule::Result] value is the grant
    def self.grant!(**options)
      Grant.call(**options)
    end

    # Gives an unclaimed grant its holder.
    #
    # @param grant [Spree::Grant]
    # @param customer [Object]
    # @return [Spree::ServiceModule::Result] value is the grant
    def self.claim!(grant, customer:)
      Claim.call(grant: grant, customer: customer)
    end

    # Consumes what the grant records, which is the kind's decision: the
    # default stamps the row, a partial kind calls the service that owns the
    # thing and answers with its refusal or its success.
    #
    # @param grant [Spree::Grant]
    # @return [Spree::ServiceModule::Result] value is the grant
    def self.consume!(grant)
      Consume.call(grant: grant)
    end

    # Takes the debt back. The row stays — it is the record that something was
    # owed — and its status says it no longer is.
    #
    # @param grant [Spree::Grant]
    # @param reason [String, nil] recorded in the row's metadata
    # @return [Spree::ServiceModule::Result] value is the grant
    def self.revoke!(grant, reason: nil)
      Revoke.call(grant: grant, reason: reason)
    end
  end
end
