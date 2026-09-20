module Spree
  module Api
    module V3
      module Store
        # The catalogue a Store API product read answers from: the store's own
        # buyable products, narrowed to the catalogs the request resolves to —
        # its channel, the buyer's company, their group — and loaded with what a
        # product row touches.
        #
        # Shared, because a second read that answers products answers them from
        # the same catalogue: a customer's purchase history is a subset of what
        # this request may see, not a set of its own
        # (docs/plans/6.1-store-api-miniprogram-gaps.md).
        module ProductCatalogue
          protected

          # @return [ActiveRecord::Relation] the products this request may buy
          def product_catalogue
            base = model_class.for_store(current_store).
                   available(Time.current, Spree::Current.currency, include_preorderable: true).
                   includes(*catalogue_includes).
                   preload_associations_lazily

            # Catalog narrowing for the buyer: their company's effective
            # catalogs, their group's, or the channel default — union of
            # assortments, resolved in one place
            # (docs/plans/6.0-b2b-companies-and-catalogs.md).
            Spree.products_for_context_service.call(
              store: current_store,
              channel: current_channel,
              customer: current_user,
              base: base
            ).value
          end

          # Associations a product row in one of these reads touches, which
          # ar_lazy_preload does not pick up on its own.
          #
          # `seller` is declared on both sides rather than left to lazy
          # preloading: the buy box asks every variant who is selling it, and a
          # variant with no seller of its own asks its product — so a listing
          # would otherwise depend on ambient behaviour to avoid an N+1 on
          # whichever of the two answers.
          #
          # @return [Array]
          def catalogue_includes
            [
              :seller,
              {
                product_publications: [],
                primary_media: [attachment_attachment: :blob, poster_attachment: :blob],
                default_variant: [:prices, stock_levels: [:stock_location, :active_stock_reservations]],
                variants: [:prices, :seller, stock_levels: [:stock_location, :active_stock_reservations]]
              }
            ]
          end
        end
      end
    end
  end
end
