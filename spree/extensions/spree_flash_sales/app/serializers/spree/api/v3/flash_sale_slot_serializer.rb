module Spree
  module Api
    module V3
      # One stretch of an activity — what the client's 开售提醒 is keyed to and
      # what a claim names.
      class FlashSaleSlotSerializer < BaseSerializer
        typelize window_status: :string, remaining: :number,
                 starts_at: [:string, nullable: true], ends_at: [:string, nullable: true],
                 purchase_cap: [:number, nullable: true]

        attributes :id, :starts_at, :ends_at

        attribute :window_status do |slot|
          slot.window_status
        end

        attribute :remaining do |slot|
          slot.flash_sale.pool_figures(slot: slot).fetch(:slot)
        end

        attribute :purchase_cap do |slot|
          slot.purchase_cap
        end
      end
    end
  end
end
