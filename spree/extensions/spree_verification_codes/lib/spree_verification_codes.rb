require 'spree_core'
require 'spree_notifications'
require 'spree_verification_codes/engine'

# Proof that the caller holds a phone number, and the second factor a balance
# spend asks for.
#
# One code service serves four flows — binding or changing the number,
# resetting a password, closing the account and the payment PIN — because the
# client cannot tell them apart at the verify step, and a check the client
# cannot express is a check that cannot be enforced
# (docs/plans/6.1-phone-verification-and-payment-pin.md).
module SpreeVerificationCodes
end
