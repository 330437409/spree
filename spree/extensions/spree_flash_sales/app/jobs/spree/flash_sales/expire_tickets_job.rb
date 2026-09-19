module Spree
  module FlashSales
    # Releases the claims whose payment window has closed.
    #
    # A late sweep delays a release; it never miscounts, because every release
    # is guarded by the ticket's own row. Continuable, because the sweep walks
    # every lapsed ticket and a deploy can land mid-run: without it a restart
    # would start again at the first one.
    class ExpireTicketsJob < Spree::BaseJob
      include ActiveJob::Continuable

      # Small enough that a busy activity never builds one enormous array, large
      # enough that the walk is worth the round trips.
      BATCH_SIZE = 500

      def perform
        step :release do |step|
          # By id, so the cursor is the last ticket released: a restart resumes
          # after it rather than walking the released rows again.
          Spree::FlashSaleTicket.lapsed.where(id: step.cursor..).order(:id).
            find_each(batch_size: BATCH_SIZE) do |ticket|
              ticket.release_expired!
              step.advance! from: ticket.id
            end
        end
      end
    end
  end
end
