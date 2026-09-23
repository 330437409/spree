module Spree
  module Transfers
    # Calls the thing's own transition, inside the caller's transaction.
    #
    # A refusal is answered as its message — the thing's own words, which is what
    # a client shows — and anything else is a bug and belongs to the caller's
    # error reporting.
    module Contract
      # @return [String, nil] the refusal, when it refused
      def self.call(method, transferable, transfer)
        return unless transferable.respond_to?(method)

        transferable.public_send(method, transfer)
        nil
      rescue Refused => e
        e.message
      end
    end
  end
end
