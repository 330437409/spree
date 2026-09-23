module Spree
  module Api
    module V3
      # The event payload for a transfer: the journey — who gave it away, where
      # it is going, and until when — and not the thing that moved, which the
      # owning domain renders from its own serializer
      # (docs/plans/6.1-transfer-primitive.md).
      #
      # The token is deliberately absent: a public read would be a bearer
      # capability, and an event payload is not where one belongs.
      class TransferSerializer < BaseSerializer
        typelize status: [:string, enum: Spree::Transfer::DISPLAY_STATUSES],
                 to_phone: [:string, nullable: true], message: [:string, nullable: true],
                 transferable_type: :string, transferable_id: 'string | null',
                 from_customer_id: 'string | null', to_customer_id: 'string | null',
                 expires_at: 'string | null', accepted_at: 'string | null',
                 canceled_at: 'string | null'

        attribute(:status) { |transfer| transfer.display_status }
        attributes :to_phone, :message
        attribute(:transferable_type) { |transfer| transfer.transferable_type }
        attribute(:transferable_id) { |transfer| transfer.transferable&.prefixed_id }
        attribute(:from_customer_id) { |transfer| transfer.from_customer&.prefixed_id }
        attribute(:to_customer_id) { |transfer| transfer.to_customer&.prefixed_id }
        attribute(:expires_at) { |transfer| transfer.expires_at&.iso8601 }
        attribute(:accepted_at) { |transfer| transfer.accepted_at&.iso8601 }
        attribute(:canceled_at) { |transfer| transfer.canceled_at&.iso8601 }
      end
    end
  end
end
