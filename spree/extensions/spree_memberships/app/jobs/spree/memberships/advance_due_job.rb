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
    class AdvanceDueJob < ApplicationJob
      queue_as Spree.queues.default

      def perform
        now = Time.current

        Spree::MembershipCard.overdue.find_each do |card|
          Spree::MembershipCards::Expire.call(card: card)
        end

        due(now).find_each do |membership|
          Spree::Memberships::Advance.call(membership: membership, now: now)
        end
      end

      private

      # Every live term the sweep has something to say about: one whose window
      # has opened, and one whose window has closed.
      #
      # @return [ActiveRecord::Relation]
      def due(now)
        table = Spree::Membership.arel_table

        Spree::Membership.live.where(table[:starts_at].lteq(now).or(table[:ends_at].lteq(now)))
      end
    end
  end
end
