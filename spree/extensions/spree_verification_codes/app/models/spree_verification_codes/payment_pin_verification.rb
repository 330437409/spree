module SpreeVerificationCodes
  # The payment PIN, as the tender sees it.
  #
  # Registered with {Spree.payment_verifications}, so the balance settlement
  # asks for it without knowing it exists and cannot be reached around it
  # (docs/plans/6.1-phone-verification-and-payment-pin.md). It is also what the
  # settle page's own verdict is computed from, so the flag a client reads and
  # the check the server makes are the same question asked once.
  class PaymentPinVerification < Spree::PaymentVerification
    # A customer with no PIN is not asked for one, and neither is one who has
    # turned the prompt off: the flag means "there is nothing to present", not
    # "this purchase skips the check".
    #
    # @param order [Spree::Order, Spree::Cart]
    # @return [Boolean]
    def required?(order:)
      pin = pin_for(order)

      pin.present? && pin.required?
    end

    # @param order [Spree::Order, Spree::Cart]
    # @param proof [String, nil] what the client sent as the PIN
    # @return [Spree::PaymentVerification::Refusal, nil]
    def verify(order:, proof:)
      pin = pin_for(order)

      # Required and then vanished: a row removed between the read and the
      # spend is a refusal rather than a free pass.
      return refusal(:required) if pin.nil?
      return nil if pin.verify(proof)

      # Only a presented-and-wrong proof is a guess. A caller that presented
      # nothing — an operator applying stored value, an internal recomputation
      # a host app runs — is refused without being counted against, or ordinary
      # back-office activity would lock the customer out of their own balance.
      pin.record_failed_attempt! if proof.present?

      refusal(pin.locked? ? :locked : :invalid)
    end

    private

    # @return [Spree::PaymentPin, nil]
    def pin_for(order)
      customer = order.customer
      return nil if customer.nil?

      Spree::PaymentPin.find_by(store: order.store, customer: customer)
    end

    # @param kind [Symbol]
    # @return [Spree::PaymentVerification::Refusal]
    def refusal(kind)
      Spree::PaymentVerification::Refusal.new(
        kind: kind.to_s,
        message: Spree.t("verification_codes.pin.#{kind}")
      )
    end
  end
end
