module Spree
  module Api
    module V3
      module Store
        # What the goods cost and whether they can be bought, in the context the
        # request carried.
        #
        # A computation rather than a record, so it carries no id: a plain Alba
        # resource is the right base here, and the item rows are their own
        # serializer rather than a hash built inside this one.
        class PricePreviewSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize currency: :string, total: [:number, nullable: true], quantity: :number,
                   purchasable: :boolean, items: 'StorePricePreviewItem[]',
                   flags: 'Record<string, unknown>', balance_not_password: :boolean

          attributes :currency

          attribute :total do |preview|
            next nil if params[:hide_prices]

            preview.total&.to_f
          end

          attribute :quantity do |preview|
            preview.quantity
          end

          attribute :purchasable do |preview|
            preview.purchasable?
          end

          attribute :flags do |preview|
            preview.flags
          end

          # The settle page's own verdict, on the settle page's own read: the
          # same question the tender asks when the balance is spent, so a client
          # is never told to skip a check the server still makes. A preview that
          # priced no cart has nothing to settle and nothing to ask for
          # (docs/plans/6.1-phone-verification-and-payment-pin.md).
          attribute :balance_not_password do |preview|
            cart = params[:cart]
            cart.nil? || !cart.balance_requires_verification?
          end

          attribute :items do |preview|
            preview.rows.map { |row| PricePreviewItemSerializer.new(row, params: params).to_h }
          end
        end
      end
    end
  end
end
