module Spree
  # A second factor a tender may demand before it spends stored value — the
  # payment PIN today, an operator's own factor tomorrow.
  #
  # The balance settlement path consults the registered verifications through
  # {Spree.payment_verifications} rather than checking anything itself, so the
  # next tender that needs one is a registration rather than an edit in the
  # money path, and a caller cannot spend a balance by reaching the tender
  # through a route that forgot the check
  # (docs/plans/6.1-phone-verification-and-payment-pin.md).
  #
  # A verification is asked twice for the same purchase: once as
  # {#required?}, which is what the settle page is told, and once as
  # {#verify} when the money is spent. The two answers must agree — a client
  # told to skip a check the server still makes has been told to fail.
  class PaymentVerification
    # Why a tender refused, in the verification's own words.
    #
    # An object rather than a string because the API maps it onto its own
    # error vocabulary: a client that cannot tell "you never set one" from
    # "that one was wrong" from "you are locked out" retries the wrong thing.
    class Refusal
      include ActiveModel::Model
      include ActiveModel::Attributes

      # What the API knows how to render. A verification may carry a kind
      # outside this list — it falls back to a generic error rather than
      # being swallowed.
      KINDS = %w[required invalid locked].freeze

      attribute :kind
      attribute :message

      validates :kind, presence: true

      # @return [String]
      def to_s
        message.to_s
      end
    end

    # Whether this verification stands between the customer and the tender for
    # this purchase.
    #
    # @param order [Spree::Order, Spree::Cart] the purchase being settled
    # @return [Boolean]
    def required?(order:)
      raise NotImplementedError
    end

    # Checks what the caller presented. Called before the tender writes, so a
    # verification that consumes what it verified does it in its own record's
    # transaction.
    #
    # @param order [Spree::Order, Spree::Cart] the purchase being settled
    # @param proof [Object, nil] what the client sent — a PIN, a code
    # @return [Spree::PaymentVerification::Refusal, nil] nil when it verifies
    def verify(order:, proof:)
      raise NotImplementedError
    end
  end
end
