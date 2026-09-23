module Spree
  module Api
    module V3
      # A term as the customer's own client reads it: whether it is holding
      # the tier yet, and the instant it ends.
      #
      # `ends_at` is an absolute instant the client renders verbatim, so
      # shortening or voiding a term needs no client change.
      class MembershipSerializer < BaseSerializer
        typelize status: :string, starts_at: 'string | null', ends_at: 'string | null'

        attributes :status
        attribute(:starts_at) { |membership| membership.starts_at&.iso8601 }
        attribute(:ends_at) { |membership| membership.ends_at&.iso8601 }
      end
    end
  end
end
