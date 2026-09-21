require 'rails/engine'

module SpreeVerificationCodes
  class Engine < Rails::Engine
    engine_name 'spree_verification_codes'

    # The tender's second factor. Registered into core's registry rather than
    # checked by a caller, so the balance spend asks for it however it is
    # reached — the cart, the order, or a route that has not been written yet
    # (docs/plans/6.1-phone-verification-and-payment-pin.md).
    config.after_initialize do
      Spree.payment_verifications << SpreeVerificationCodes::PaymentPinVerification.new

      # The customer write asks this before it believes a phone number, and
      # core asks it without knowing what a verification code is. Assigned
      # only where nothing has: a deployment that named its own service keeps
      # it.
      Spree::Dependencies.customer_phone_verification_service ||= 'Spree::VerificationCodes::VerifyPhone'
    end

    # A code is five minutes of somebody's identity and a PIN is the key to
    # their balance: neither may reach a log, and both arrive as parameters.
    # Filtered where they enter, the way core filters a password.
    initializer 'spree_verification_codes.params.filter' do |app|
      app.config.filter_parameters += %i[code verification_code pay_password pin]
    end
  end
end
