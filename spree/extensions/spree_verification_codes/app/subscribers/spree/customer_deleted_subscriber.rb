module Spree
  # A customer destroyed outright takes their PIN with them.
  #
  # The erasure flow is the sanctioned way to forget a person and this gem
  # extends it from its own hooks; this is the other way a row is orphaned —
  # the admin API can delete a customer, and so can an app — and it is a
  # subscriber rather than a `dependent: :destroy` because a gem may not add
  # an association to a core model
  # (docs/plans/6.1-phone-verification-and-payment-pin.md).
  #
  # The codes need no counterpart: they are keyed by a number rather than by a
  # customer, and expire within minutes of being sent.
  class CustomerDeletedSubscriber < Spree::Subscriber
    subscribes_to 'customer.deleted'

    # @param event [Spree::Event]
    # @return [void]
    def handle(event)
      customer_id = Spree.customer_class.decode_own_prefixed_id(event.payload['id'])
      return if customer_id.nil?

      # Deleted rather than marked: the row is a credential for an account
      # that no longer exists.
      Spree::PaymentPin.with_deleted.where(customer_id: customer_id).delete_all
    end
  end
end
