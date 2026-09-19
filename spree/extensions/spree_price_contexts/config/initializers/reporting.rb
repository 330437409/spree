# The provenance of the price a line carries, for the reports that have to say
# which price they are reading (docs/plans/6.1-seller-scoped-pricing.md).
#
# A line priced through a price list names it, and a list is what a context
# prices through — so "what did the offline channel sell at" is gross sales
# grouped by this dimension. A line with **no** list carries a base price, which
# is the seller's own (its offer variant's price) or the operator's: that is the
# category the EU Omnibus rule tracks, and grouping the two together is how a
# report ends up quoting a segmented price as if it were the price.
Spree.reporting.dimension :price_list, base: :line_items, column: :price_list_id, lookup: :price_list,
                          subject: -> { Spree::PriceList }, key_scope: 'read_products',
                          resolve: ->(store, value) { store.price_lists.find_by_prefix_id!(value).id },
                          hydrate: lambda { |store, ids, _params|
                            store.price_lists.includes(:price_adjustment_tiers).where(id: ids).to_h do |list|
                              [list.id, { id: list.prefixed_id, label: list.name,
                                          meta: { automatic: list.automatic_pricing? } }]
                            end
                          }

# Which source answered the price: nil is the platform's own pricing walk (a
# base price, or a list's), `manual` is a negotiated price an admin set on the
# line, and any other value names the pricing provider that quoted it.
Spree.reporting.dimension :price_source, base: :line_items, column: :price_source
