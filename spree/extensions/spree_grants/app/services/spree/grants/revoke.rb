module Spree
  module Grants
    # Takes the debt back.
    #
    # The row stays: it is the record that something was owed, and why it
    # stopped being owed is the operation's own business. What was consumed
    # cannot be taken back here — undoing that is the owning plan's, which
    # knows what it would have to return.
    class Revoke
      prepend Spree::ServiceModule::Base

      # @param grant [Spree::Grant]
      # @param reason [String, nil] recorded in the row's metadata
      # @return [Spree::ServiceModule::Result] value is the grant
      def call(grant:, reason: nil)
        return success(grant) if grant.revoked?
        return failure(grant, :already_consumed) if grant.consumed?

        grant.metadata = grant.metadata.merge('revocation_reason' => reason) if reason.present?
        grant.update!(status: 'revoked')

        success(grant)
      end
    end
  end
end
