module Spree
  module Authentication
    # Raised when a provider profile carries no email and the caller used an
    # entry point that cannot ask for one. The account has not been created:
    # a placeholder address would leave the shopper unable to ever supply a
    # real one, so the caller must collect it and complete the registration.
    class RegistrationRequired < StandardError
      def initialize(message = nil)
        super(message || Spree.t('errors.messages.registration_required'))
      end
    end
  end
end
