module Spree
  module Transfers
    # Calls the thing's own transition, inside the caller's transaction.
    #
    # A refusal is answered as its message — the thing's own words, which is what
    # a client shows — and anything else is a bug and belongs to the caller's
    # error reporting.
    #
    # A thing that is *gone* is a refusal too, and this is the only place that can
    # say so: the window outlives what it carries (a card destroyed by an admin
    # cleanup, a customer's own deletion), and the row's own `belongs_to` will not
    # catch it, because a foreign key that is not changing is never revalidated.
    module Contract
      # @return [String, nil] the refusal, when it refused
      def self.call(method, transferable, transfer)
        return Spree.t('transfers.errors.transferable_gone') if transferable.nil?
        return unless transferable.respond_to?(method)

        transferable.public_send(method, transfer)
        nil
      rescue Refused => e
        e.message
      end
    end
  end
end
