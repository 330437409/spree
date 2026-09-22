module Spree
  module SellerTransfers
    # Takes back part of what a seller was credited, after a refund.
    #
    # Written as its own negative row rather than by editing the credit, so what
    # a seller has earned is always the sum of their transfers and the history
    # stays readable. If the credit was already settled in a closed payout, the
    # reversal simply lands in the next period — a settlement that happened is
    # never rewritten.
    #
    # **Every credit the order carries is reversed, not only the earning.** A
    # subsidy is the platform's own money, added because the platform funded
    # part of the price, so a refunded sale must not leave it with the seller.
    # Each credit gets its own reversal row, keyed to the credit it reverses.
    #
    # The ledger rows are written in every tier. Whether money is actually
    # pulled back is the provider's business, and the built-in one pulls back
    # nothing.
    class Reverse < Spree::Workflow
      hooks :validate, :after_reverse

      attr_reader :reversals

      # @param order [Spree::Order] the seller order being refunded
      # @param amount [BigDecimal, Numeric] how much of the order was refunded
      # @param refund [Spree::Refund, nil] what caused the clawback. Part of the
      #   reversal's natural key, so a redelivered event reverses once.
      # @return [Spree::ServiceModule::Result] value is the earning's reversal,
      #   or the order when there was nothing to reverse
      def perform(order:, amount:, refund: nil)
        super

        step :find_credits
        step :replay_existing
        run_hooks :validate

        step :build_reversals
        external_step :execute_reversals
        run_hooks :after_reverse

        success(reversal)
      end

      # The one row a caller most often wants: what the refund took back from
      # the earning. A subsidy only ever reverses alongside an earning, so this
      # is the answer for the money the refund is about.
      #
      # @return [Spree::SellerTransfer, nil]
      def reversal
        @reversal
      end

      private

      # Every credit this order carries, the earning first: it is the row a
      # caller reads, and both halt paths answer with the first of them.
      def find_credits
        @credits = Spree::SellerTransfer.credits.where(order_id: order.id).order(:id).to_a
        # Nothing was ever credited — the order was refunded before it shipped,
        # which is the ordinary case and not an error.
        halt!(order) if @credits.empty?
      end

      # An event can be delivered twice, and a job can retry. What a redelivery
      # leaves to do is whatever this refund has not already reversed — which
      # can be one credit out of two, if the first attempt got only that far —
      # and with nothing left it is answered with the reversal already written.
      def replay_existing
        @pending = @credits.reject { |credit| reversal_for(credit).present? }
        return if @pending.any?

        halt!(@credits.filter_map { |credit| reversal_for(credit) }.first)
      end

      # @return [Spree::SellerTransfer, nil] this refund's reversal of that credit
      def reversal_for(credit)
        return if refund.nil?

        @reversals_for ||= {}
        @reversals_for[credit.id] ||= Spree::SellerTransfer.reversals_only.
                                      find_by(refund_id: refund.id, reversed_from_id: credit.id)
      end

      def build_reversals
        earning = @credits.find(&:earning?)
        carry = clawback_fraction(earning)

        @reversals = @pending.filter_map { |credit| write_reversal(credit, earning, carry) }
        halt!(order) if @reversals.empty?

        @reversal = @reversals.find { |row| row.reversed_from.earning? } || @reversals.first
      end

      # What share of the order's credit this refund takes back, as a fraction
      # of it.
      #
      # The earning answers with the refund's own detail; the subsidy follows
      # that fraction exactly, so what the seller gives back always carries the
      # same proportion of what the platform added. With no earning to follow —
      # a subsidy is never written without one, but an earning can be fully
      # reversed away before the next refund lands — the order's own ratio
      # answers.
      #
      # @return [BigDecimal]
      def clawback_fraction(earning)
        return order_ratio if earning.nil? || earning.amount.zero?

        existing = reversal_for(earning)
        credited = existing ? existing.amount.abs : seller_share_of(amount, earning)

        [credited / earning.amount, BigDecimal(1)].min
      end

      # @return [BigDecimal] the refunded share of the order, capped at all of it
      def order_ratio
        total = order.total.to_d
        return BigDecimal(1) if total.zero?

        [amount.to_d.abs / total, BigDecimal(1)].min
      end

      # Bounded and written under the credit's own lock, so two refunds landing
      # together cannot each read the same untouched credit and each take the
      # whole of it. The unique index on (refund, reversed row) covers the other
      # race — the same refund arriving twice — and resolves to the row that
      # won rather than failing the caller.
      #
      # @return [Spree::SellerTransfer, nil] nil when there is nothing left to take
      def write_reversal(credit, earning, carry)
        credit.with_lock do
          bounded = [share_of(credit, earning, carry), credit.reversible_amount].min
          next nil if bounded <= 0

          Spree::SellerTransfer.create!(
            store: credit.store,
            seller: credit.seller,
            order: order,
            reversed_from: credit,
            refund: refund,
            # Negative, so what a seller has earned is the plain sum of the rows.
            amount: -bounded,
            currency: credit.currency,
            kind: 'refund_reversal',
            provider: credit.provider,
            status: 'pending',
            **settlement_of(credit, bounded)
          )
        end
      rescue ActiveRecord::RecordNotUnique
        # Only a refund-keyed reversal can collide, since that index is what
        # makes it unique. Re-raising anything else keeps the real error
        # visible rather than replacing it with a lookup that cannot succeed.
        raise if refund.nil?

        reversal_for(credit) || raise
      end

      # What one credit gives back. The earning is answered from the refund's
      # own detail; the subsidy at the fraction the earning came back at, which
      # keeps the two in step however the refund was attributed.
      #
      # @return [BigDecimal]
      def share_of(credit, earning, carry)
        return seller_share_of(amount, earning) if credit.earning?

        Spree::Money::Rounding.to_currency(carry * credit.amount, credit.currency)
      end

      # The seller's share of a refunded amount.
      #
      # A refund is the customer's gross figure — it carries the tax and the
      # marketplace's commission, while the seller only ever received their net
      # cut. Taking the gross back would charge them the commission on goods
      # that came back, so what comes back is always the seller's share of it.
      #
      # Which share depends on what the refund can say about itself. A return or
      # a claim names the lines it paid for, and those lines earned a knowable
      # amount. Anything else — a manual refund, a cancellation — is only an
      # amount against an order, and the order's own ratio is the best available
      # answer.
      # Memoised: the fraction the subsidy follows and the earning's own
      # reversal ask the same question of the same refund.
      def seller_share_of(refunded, earning)
        @seller_share ||= attributed_share(refunded, earning) || blended_share(refunded, earning)
      end

      # What the named lines actually earned, scaled to what this refund paid.
      #
      # The scaling is not a refinement: one return is refunded once per payment
      # it draws on, and every one of those refunds names the same lines. Taking
      # them at face value would claw the same units back once per payment.
      # Scaling also absorbs an operator who refunded a different amount than the
      # lines are worth — a restocking fee, or goodwill on top.
      #
      # Nil when the refund names nothing, which sends the caller to the blend.
      def attributed_share(refunded, earning)
        amounts = refund&.refunded_line_amounts
        return if amounts.blank?

        gross = amounts.values.sum.to_d
        return if gross <= 0

        # Nil from any line means the attribution cannot be trusted whole, so
        # the blend answers for the refund rather than part of it.
        earnings = amounts.map { |line_item_id, amount| line_earning(line_item_id, amount.to_d) }
        return if earnings.any?(&:nil?)

        Spree::Money::Rounding.to_currency(earnings.sum * (refunded.to_d.abs / gross), earning.currency)
      end

      def blended_share(refunded, earning)
        paid = order.total.to_d
        return refunded.to_d.abs if paid.zero?

        Spree::Money::Rounding.to_currency(refunded.to_d.abs * (earning.amount / paid), earning.currency)
      end

      # What one line's refunded value earned the seller: their money less the
      # commission charged on it, and less the consumer tax when the marketplace
      # remits it — mirroring how the earning itself was worked out.
      #
      # The commission comes from the row written against that line at
      # placement, not from today's rate: rates change, a clamped fee is not the
      # rate times the base, and a fixed rate is charged per unit.
      def line_earning(line_item_id, amount)
        line_item = order_line_items[line_item_id]
        paid = line_item&.amount.to_d
        # A line this order does not carry, or one worth nothing, says nothing
        # about what the seller earned. Answering the gross would claw back the
        # commission and the tax they never received, which is the whole thing
        # this is here to avoid, so the caller falls back to the order's ratio.
        return if paid.zero?

        # Only ever a fraction of the line, so a clamped commission is divided
        # rather than reasoned about — the best available attribution.
        share = amount / paid
        earned = amount - (commission_totals[line_item_id].to_d * share)
        earned -= line_item.tax_total.to_d * share if order.seller&.tax_remittance == 'platform'
        earned
      end

      def order_line_items
        @order_line_items ||= order.line_items.index_by(&:id)
      end

      def commission_totals
        @commission_totals ||= Spree::CommissionLine.for_line_items.
                               where(line_item_id: order_line_items.keys).
                               pluck(:line_item_id, :total).to_h
      end

      # A clawback has to settle where its credit settled. Payouts are swept by
      # settlement currency, so a reversal left in the sale's currency would
      # never join the batch that pays the row it cancels — the seller would be
      # paid in full for goods that came back, and the row would sit in a
      # currency their account cannot pay.
      #
      # Prorated from the credit's own settled figure rather than converted at
      # today's rate, so the money comes back at the rate it went out at.
      def settlement_of(credit, bounded)
        return {} if credit.settled_amount.blank? || credit.amount.zero?

        share = credit.settled_amount * (bounded / credit.amount)

        {
          settled_amount: -Spree::Money::Rounding.to_currency(share, credit.settlement_currency),
          settled_currency: credit.settled_currency
        }
      end

      # Every row gets its attempt, and the first refusal is the answer — with
      # its own row and its own message, so an operator reconciling reads a
      # pair that belongs together.
      def execute_reversals
        failed = @reversals.filter_map { |row| execute_reversal(row) }.first

        failure(failed[:row], failed[:message]) if failed
      end

      # @return [Hash, nil] nil when the provider took it back, else the row and
      #   what the provider said
      def execute_reversal(row)
        provider_for(row).reverse!(row)
        nil
      rescue Spree::Core::AmbiguousGatewayError => e
        # Whether the clawback happened is the provider's to say. Recorded as
        # such rather than as a refusal, so an operator reconciling knows which
        # rows are questions and which are simply owed.
        row.update!(status: 'unresolved')
        report(row, e)
      rescue StandardError => e
        row.update!(status: 'processing')
        report(row, e)
      end

      # @return [Hash] the row and the provider's own words
      def report(row, error)
        Rails.error.report(error, handled: true, context: { seller_transfer_id: row.id }, source: 'spree.core')

        { row: row, message: error.message }
      end

      # The provider that made the money, not whichever one the store uses now.
      # A marketplace that changes provider still has money sitting with the
      # old one, and asking the new one to reverse a transfer it never made
      # leaves the original standing — the seller keeps a refunded sale.
      #
      # Keyed by the provider name, since one refund can reverse rows made by
      # two — the earning and the subsidy are written when each is, and a store
      # that changed provider in between made them with different ones.
      def provider_for(row)
        @providers ||= {}
        @providers[row.provider] ||= begin
          configured = Spree.payout_providers.find { |candidate| candidate.to_s == row.provider }

          # No silent fallback to whatever the store uses now. A provider that
          # is no longer installed still holds the transfer this reverses, and
          # handing the job to a different one would mark the row reversed
          # while the money stayed where it was. An operator has to know.
          if configured.nil?
            raise Spree::Core::GatewayError,
                  "Payout provider #{row.provider} is not registered, so its transfer cannot be reversed"
          end

          configured.new
        end
      end
    end
  end
end
