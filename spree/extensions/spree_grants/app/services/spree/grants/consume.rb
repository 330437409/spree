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
        # A kind answers with {Spree::Grants::Kind.accept} or
        # {Spree::Grants::Kind.refuse}; anything else is a contract it has not
        # met, refused here rather than raised at the caller.
        return failure(grant, :unexpected_answer) unless result.is_a?(Spree::ServiceModule::Result)
        return result if result.error.nil? || result.error.is_a?(Spree::ServiceModule::ResultError)

        # …and a kind that built its own result around a bare reason still
        # answers in the shape this door promises.
        Spree::ServiceModule::Result.new(result.success, result.value,
                                        Spree::ServiceModule::ResultError.new(result.error))
      end
    end
  end
end
