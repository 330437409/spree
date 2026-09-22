module Spree
  module SellerTransfers
    # Credits a seller for one order whose goods have gone out.
    #
    # The first level of the ledger. What the seller earned is their sale less
    # what the marketplace charged them, and it is **payment-source-agnostic**:
    # store credit and gift cards are how the customer paid, which is the
    # platform's funding concern. The seller is owed their cut either way.
    #
    # A second row goes beside the earning when the platform — not the seller —
    # funded part of the price: a **subsidy**, the seller's shortfall against
    # what the sale would have earned at the shelf price. Whoever promised that
    # funding contributes it through the `funded_discounts` hook; this workflow
    # owns the arithmetic, the ledger row and the hand-off, so a seller is
    # never credited for a discount the seller gave.
    #
    # Idempotent by the unique index on `(order_id) WHERE kind = 'earning'` —
    # the fulfillment event can fire more than once (it is dual-emitted under a
    # legacy name for one release), and a re-fired event must find the earning
    # that exists rather than credit the seller twice — and by the same index
    # on the subsidy.
    class Create < Spree::Workflow
      hooks :validate, :funded_discounts, :after_create

      # The earning, and the platform's own row beside it when one was funded.
      attr_reader :seller_transfer, :subsidy

      # @param order [Spree::Order] the seller's order, fully fulfilled
      # @return [Spree::ServiceModule::Result] value is the Spree::SellerTransfer,
      #   or the order when there is nothing to credit
      def perform(order:)
        super

        step :ensure_creditable
        step :replay_existing
        run_hooks :validate

        step :build_transfer
        # What whoever promised the platform's money contributed: the reduction
        # they funded, per line. Read once the earning exists, so an extension
        # that raises cannot cost the seller the money they are owed.
        @funding = run_hooks :funded_discounts
        step :build_subsidy
        external_step :execute_transfer
        external_step :execute_subsidy
        run_hooks :after_create

        success(seller_transfer)
      end

      private

      # A first-party order earns nobody anything — the money is already the
      # operator's. Nor does an order whose goods have not all gone out, or one
      # with no goods at all: `fully_fulfilled?` answers true for an order with
      # no fulfillments, since none of nothing is outstanding.
      def ensure_creditable
        halt!(order) if order.seller_id.blank?
        halt!(order) if order.fulfillments.empty?
        halt!(order) unless order.fully_fulfilled?
      end

      def replay_existing
        existing = Spree::SellerTransfer.earnings.find_by(order_id: order.id)
        halt!(existing) if existing
      end

      def build_transfer
        @seller_transfer = Spree::SellerTransfer.create!(
          store: order.seller.store,
          seller: order.seller,
          order: order,
          amount: earned_amount,
          currency: order.currency,
          kind: 'earning',
          provider: provider_name,
          status: 'pending'
        )
      rescue ActiveRecord::RecordNotUnique
        # Another delivery of the same event got there first; the unique index
        # is what makes that safe, and its winner is the answer.
        halt!(Spree::SellerTransfer.earnings.find_by!(order_id: order.id))
      end

      # The platform's own promise, as its own row beside the earning. Nothing
      # is written when no handler contributed funding, which is every order
      # the platform did not discount.
      def build_subsidy
        @subsidy = nil
        return if funding_amount <= 0

        @subsidy = Spree::SellerTransfer.create!(
          store: order.seller.store,
          seller: order.seller,
          order: order,
          amount: funding_amount,
          currency: order.currency,
          kind: 'subsidy',
          provider: provider_name,
          status: 'pending',
          metadata: funding_metadata
        )
      rescue ActiveRecord::RecordNotUnique
        # Another delivery got there first, exactly as with the earning. Its row
        # is left to that delivery to hand over; this one has nothing to send.
        @subsidy = Spree::SellerTransfer.subsidies.find_by(order_id: order.id)
      end

      # Outside any transaction: a provider that moves money makes a network
      # call here, and a row lock must not be held across it.
      def execute_transfer
        hand_to_provider(seller_transfer)
      end

      def execute_subsidy
        hand_to_provider(subsidy)
      end

      # Only a row nobody has sent: a delivery that arrives after another one
      # handed the same row over must not send it twice, and `pending` is
      # exactly the state a row the provider never got is left in — the retry
      # job is what picks that up.
      def hand_to_provider(row)
        return if row.nil? || !row.pending?
        # A seller the provider cannot pay yet keeps the credit as a pending
        # row. Verification can take days, and an account can lose the
        # capability again — either way the money is owed, and
        # `SellerTransfers::ExecutePendingJob` sends it once they are payable,
        # or on its next scheduled run if that moment went unseen.
        return unless order.seller.payouts_enabled?

        provider.transfer!(row)
      rescue Spree::Core::AmbiguousGatewayError => e
        # Nobody knows whether the money moved, so nothing may send it again:
        # the retry job takes `pending` and `processing` rows, and an
        # idempotency key only covers a retry while the provider keeps its
        # record. Parked where no automatic attempt reaches it, for an
        # operator to resolve against the provider's own books.
        row.update!(status: 'unresolved')
        Rails.error.report(e, handled: true, context: { seller_transfer_id: row.id },
                              source: 'spree.core')
        failure(row, e.message)
      rescue StandardError => e
        # A definite refusal — the money did not move, so the credit is still
        # owed and the retry job picks it up.
        row.update!(status: 'processing')
        Rails.error.report(e, handled: true, context: { seller_transfer_id: row.id },
                              source: 'spree.core')
        failure(row, e.message)
      end

      # What the platform owes, worked out from what handlers contributed.
      #
      # Each discounted line is credited its reduction less the commission the
      # platform did not charge on it: the rate is the one the sale was charged
      # at, read off the line's own commission row, and only a percentage rate
      # moves with the price — a flat fee charges the same on a discounted line
      # as on any other, so none of that discount costs the seller.
      #
      # Persisted, never recomputed: the shelf price a discount is measured
      # against can move after the sale.
      def funding_amount
        @funding_amount ||= begin
          rates = percentage_rates
          total = funded_discounts.sum do |line_item_id, discount|
            discount.to_d * (1 - rates[line_item_id.to_i].to_d)
          end

          Spree::Money::Rounding.quantize(total, Spree::Money::Rounding.precision(order.currency))
        end
      end

      # @return [Hash{Integer => BigDecimal}] what each line was reduced by
      def funded_discounts
        @funded_discounts ||= contributed(:discounts).to_h.transform_keys(&:to_i)
      end

      def funding_metadata
        contributed(:metadata).merge('funded_discount' => funded_discounts.values.sum.to_d.to_s)
      end

      def contributed(key)
        return {} unless @funding.is_a?(Hash)

        (@funding[key] || @funding[key.to_s] || {}).to_h
      end

      # The percentage rate charged on each discounted line, as a fraction. A
      # line with no commission row — no rate matched it — answers nothing, so
      # the whole of its discount is the seller's shortfall.
      def percentage_rates
        Spree::CommissionLine.for_line_items.
          where(order_id: order.id, line_item_id: funded_discounts.keys).
          each_with_object({}) do |line, rates|
            rates[line.line_item_id] = line.rate.to_d / 100 if line.kind == 'percentage'
          end
      end

      # What the seller earned: their sale, less the marketplace's commission
      # including the VAT charged on it — the platform invoices the seller for
      # both, and the seller reclaims that VAT as input tax.
      #
      # A platform-remitted seller does not receive the consumer tax either,
      # since the marketplace files it (Decision 9).
      def earned_amount
        base = order.total.to_d
        # Both halves of the consumer tax, because a market decides which one
        # it uses: added on top where prices are quoted net, folded into the
        # price where they are quoted gross. A marketplace that remits the tax
        # and only subtracts the added half pays a tax-inclusive seller the VAT
        # as well as paying it to the tax authority.
        base -= order.tax_total.to_d if order.seller.tax_remittance == 'platform'

        # Summed from the rows rather than read off order.commission_total:
        # the column is a reporting figure refreshed when commission is
        # charged, and money leaving the platform is settled against the
        # settlement records themselves.
        [base - order.commission_lines.sum(:total).to_d, 0].max
      end

      def provider
        @provider ||= order.store.payout_provider_instance
      end

      def provider_name
        provider.class.provider_key
      end
    end
  end
end
