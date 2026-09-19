module SpreeServiceAreas
  # The seller has published where they deliver.
  #
  # A requirement kind rather than a validation on the seller, because a
  # marketplace composes its own checklist: this deployment always adds the row,
  # and a marketplace that has no use for service areas simply never creates it.
  #
  # Satisfied by a bound warehouse rather than by any warehouse: a shop with
  # stock but no binding serves nowhere, and the routing says so at the first
  # order — which is later than a seller should learn it. Deactivated warehouses
  # do not count, because they are not part of what the shop currently serves.
  class ServiceAreaRequirement < Spree::SellerRequirement
    # @param seller [Spree::Seller]
    # @return [Boolean]
    def met_by_seller?(seller)
      seller.stock_locations.active.where.not(administrative_division_id: nil).exists?
    end
  end
end
