module Spree
  module Api
    module V3
      # What a customer holds: the units, the deadline the client counts down
      # to, and which activity and stretch they are for.
      class FlashSaleTicketSerializer < BaseSerializer
        typelize quantity: :number, expires_at: :string

        attributes :status, :quantity, :expires_at

        attribute :variant_id do |ticket|
          ticket.variant&.prefixed_id
        end

        attribute :flash_sale_id do |ticket|
          ticket.flash_sale&.prefixed_id
        end

        attribute :flash_sale_slot_id do |ticket|
          ticket.flash_sale_slot&.prefixed_id
        end
      end
  end
end
end
