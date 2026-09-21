module Spree
  module Api
    module V3
      module Store
        # The two facts the client's own settings page renders three states
        # from: whether a PIN exists, and whether a balance spend asks for it.
        #
        # Answered whether or not one exists — "no PIN" is a state the page
        # offers 去设置 for, not a 404 — and carrying no timestamps or
        # identifiers, because neither is the customer's business and a PIN has
        # no id to give.
        class PaymentPinSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize set: :boolean, required: :boolean

          # The client's `havePayPasswd`.
          attribute :set do |pin|
            pin.present?
          end

          # The client's `display`.
          attribute :required do |pin|
            pin.present? ? pin.required? : false
          end
        end
      end
    end
  end
end
