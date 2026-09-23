module Spree
  module Memberships
    # Advances every term whose window moved, and expires every card whose
    # deadline to be activated passed.
    #
    # The sweep, moved here from spree_crm's `ExpireLapsedJob` (ruled 2026-09-18)
    # so that one engine owns the term and the group it holds. The host
    # application registers it as a recurring task — this gem cannot add itself
    # to `config/recurring.yml`.
    #
    # A term that ran out is ended, and ending it is what lets the customer's
    # next term start: a purchased upgrade takes the tier's group when the term
    # it replaces is over, which is the client's own 自{lowEndTime}起 promise.
    #
    # Continuable, because the sweep walks every term a store has and a deploy
    # can land mid-run: without it a restart would begin again at the first one
    # and re-advance the terms it already advanced.
    class AdvanceDueJob < Spree::BaseJob
      include ActiveJob::Continuable

      # Small enough that a busy store never builds one enormous array, large
      # enough that the walk is worth the round trips.
      BATCH_SIZE = 500

      def perform
        step :expire_cards do |step|
          Spree::MembershipCard.overdue.where(id: step.cursor..).order(:id).
            find_each(batch_size: BATCH_SIZE) do |card|
              guarded(card) { Spree::MembershipCards::Expire.call(card: card) }
              step.advance! from: card.id
            end
        end

        step :advance_terms do |step|
          now = Time.current

          # By id, so a restart resumes after the last term advanced rather than
          # walking the ones already dealt with again.
          Spree::Membership.due(now).where(id: step.cursor..).order(:id).
            find_each(batch_size: BATCH_SIZE) do |membership|
              guarded(membership) { Spree::Memberships::Advance.call(membership: membership, now: now) }
              step.advance! from: membership.id
            end
        end
      end

      # One row nobody can advance — a customer who is gone, a window that
      # cannot be written — must not stop the sweep for every term behind it,
      # because the next run would start at the same row again.
      def guarded(record)
        yield
      rescue StandardError => e
        Rails.error.report(e, handled: true, context: { membership_id: record.try(:id) }, source: 'spree.core')
      end
    end
  end
end
