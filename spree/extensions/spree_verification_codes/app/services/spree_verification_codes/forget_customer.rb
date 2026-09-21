module SpreeVerificationCodes
  # What erasure does to this gem's rows.
  #
  # The anonymization flow is the only sanctioned erasure path, and it says in
  # its own words that a table carrying customer-identifiable data extends it
  # in the same change. Two of this gem's columns qualify: the code's `phone`,
  # which is the fact the flow already clears on the customer and their
  # addresses, and the PIN, a credential that would otherwise outlive the
  # account it guards and stay verifiable against the row.
  #
  # Both are deleted rather than redacted — a code is a spent credential and a
  # PIN guards an account that no longer exists — and deleted *hard*, because
  # these models are paranoid and a soft delete leaves the phone in the table.
  class ForgetCustomer
    # Two hooks, because the flow's own hooks run after its steps have already
    # rewritten the number: the first remembers it while it is still there.
    PHONE_KEY = :spree_verification_codes_erased_phone

    # @param workflow [Spree::Customers::Anonymize]
    # @return [void]
    class RememberPhone
      def self.call(workflow)
        RequestStore.store[PHONE_KEY] = workflow.customer&.phone
      end
    end

    # @param workflow [Spree::Customers::Anonymize] the flow, which runs with
    #   the erased customer in hand
    # @return [void]
    def self.call(workflow)
      customer = workflow.customer
      phone = RequestStore.store.delete(PHONE_KEY)

      Spree::PaymentPin.with_deleted.where(customer_id: customer.id).delete_all if customer.present?

      return if phone.blank?

      Spree::VerificationCode.with_deleted.where(
        phone: Spree::VerificationCode.normalize_phone(phone)
      ).delete_all
    end
  end
end
