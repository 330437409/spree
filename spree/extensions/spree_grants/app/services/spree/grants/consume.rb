module Spree
  module Grants
    # Consumes what the grant records.
    #
    # The primitive refuses what is not usable — expired, already consumed or
    # revoked — and hands everything else to the kind. What consuming means is
    # the kind's answer, and so is the refusal a kind gives when it has
    # nothing left to consume.
    class Consume
      prepend Spree::ServiceModule::Base

      # @param grant [Spree::Grant]
      # @return [Spree::ServiceModule::Result] value is the grant
      def call(grant:)
        return failure(grant, :not_usable) unless grant.usable?

        kind = grant.kind_class
        return failure(grant, :unknown_kind) if kind.nil?

        result = kind.consume!(grant)
        # A kind that builds its own result instead of using its own helpers
        # still answers in the shape this door promises.
        return result if result.error.nil? || result.error.is_a?(Spree::ServiceModule::ResultError)

        Spree::ServiceModule::Result.new(result.success, result.value,
                                        Spree::ServiceModule::ResultError.new(result.error))
      end
    end
  end
end
