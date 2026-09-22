module Spree
  module Memberships
    # Stands up a tier's member price: a catalogue of the tier's own, an owned
    # automatic price list, and the assignment that shows it to the tier's
    # group.
    #
    # A percentage is only expressible on a catalogue-owned list — a standalone
    # one refuses it (`PriceList#percentage_requires_catalog`) — and a
    # catalogue-owned list is consulted before the store's own, so a member
    # price beats a store-wide agreement instead of losing to it. The tier's
    # group is the whole audience: nothing else has to match.
    #
    # The catalogue carries no assortment, and an empty assortment hides
    # nothing, so the tier prices the shop rather than curating it.
    #
    # The price is the operator's promise and the operator funds it: what a
    # member does not pay, the platform credits the seller back
    # (`funded_discounts` on Spree::SellerTransfers::Create).
    class SetMemberDiscount
      prepend Spree::ServiceModule::Base

      # @param tier_setting [Spree::MembershipTierSetting]
      # @param percentage [Numeric, String, nil] how much comes off the shelf
      #   price, as a positive percentage — `10` is 10% off. Nil and zero take
      #   the price out of effect and keep the setup for when it is wanted
      #   again.
      # @return [Spree::ServiceModule::Result] value is the catalogue the tier
      #   prices through, or nil when there is nothing to set one up on
      def call(tier_setting:, percentage:)
        store = tier_setting.store
        return failure(nil, :store_missing) if store.nil?

        catalog = catalog_for(tier_setting, store)
        return failure(nil, :catalog_unavailable) if catalog.nil?

        discount = percentage.to_d
        return switch_off(catalog) unless discount.positive?

        result = write_price_list(tier_setting, catalog, discount)
        return result unless result.success?

        switch_on(catalog)
      end

      private

      # The catalogue this tier already prices through, or a fresh one carrying
      # the tier's own name, so an operator reading the catalogue list sees
      # which tier it belongs to.
      #
      # The link is assigned on the record the caller handed in, for the
      # caller's own save to persist: a tier is usually priced as part of its
      # own save, and a second one inside that would recur.
      #
      # @return [Spree::Catalog, nil]
      def catalog_for(tier_setting, store)
        return tier_setting.catalog if tier_setting.catalog

        result = Spree::Catalogs::Create.call(
          store: store,
          attributes: {
            name: Spree.t('memberships.tier_catalog_name', name: tier_setting.name),
            assignables: [tier_setting.customer_group].compact,
            metadata: { 'membership_tier_setting_id' => tier_setting.id }
          }
        )
        return nil if result.failure?

        tier_setting.catalog = result.value

        result.value
      end

      # The list the tier prices through. Its percentage is stored negative,
      # because a list's factor is `1 + percentage / 100`: -10 is 0.9, which is
      # what ten percent off means.
      def write_price_list(tier_setting, catalog, discount)
        Spree::Catalogs::SetPriceList.call(
          catalog: catalog,
          attributes: {
            name: Spree.t('memberships.tier_price_list_name', name: tier_setting.name),
            price_adjustment_percentage: -discount
          }
        )
      end

      # Setting a price is what puts the agreement in effect: the catalogue is
      # born in draft, and the list inside it is created live — so a list an
      # operator deactivated directly is the only one this brings back, and a
      # live one is left alone rather than reactivated on every write.
      #
      # The list goes live before the catalogue does: a catalogue in effect with
      # nothing to price through would be an audience with no prices.
      def switch_on(catalog)
        list = catalog.price_list
        unless list.active_or_scheduled?
          result = Spree::PriceLists::Activate.call(price_list: list)
          return result if result.failure?
        end

        Spree::Catalogs::Activate.call(catalog: catalog)
      end

      # Taken out of effect, not dismantled: the list, its assignment and the
      # catalogue all survive, so a price that returns resumes exactly what was
      # there.
      def switch_off(catalog)
        Spree::Catalogs::Deactivate.call(catalog: catalog)
      end
    end
  end
end
