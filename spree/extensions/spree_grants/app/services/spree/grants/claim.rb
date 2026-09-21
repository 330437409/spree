module Spree
  module Grants
    # Gives an unclaimed grant its holder.
    #
    # What a code that was drawn by a campaign and handed to a friend does:
    # until somebody claims it the debt belongs to nobody, and the claim is
    # what puts a customer on the row. Claiming it twice by the same customer
    # is a no-op, because a client that retries is not a second claim; two
    # customers claiming at once is one claim, which the row decides rather
    # than this service.
    class Claim
      prepend Spree::ServiceModule::Base

      # @param grant [Spree::Grant]
      # @param customer [Object]
      # @return [Spree::ServiceModule::Result] value is the grant
      def call(grant:, customer:)
        return failure(grant, :not_usable) unless grant.usable?
        return success(grant) if grant.customer_id == customer.id
        return failure(grant, :already_claimed) if grant.customer_id.present?

        return failure(grant, :already_claimed) unless grant.claim!(customer)

        success(grant.reload)
      end
    end
  end
end
