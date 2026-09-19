namespace :spree do
  namespace :price_contexts do
    desc <<~DESC
      Creates the three price-context channels a storefront asks in — 区域, 现场推广 and
      线下 — under every store that does not have them yet:

        bin/rails spree:price_contexts:install_channels

      The channels are created with the codes the client already sends as `cartType`
      (area, scene, offline) and with their names in each store's own admin locale; an
      operator renames them freely, because the code is what the wire carries.

      It creates the channel and nothing else. Which catalogue a context prices
      through, and the price list inside it, are the merchant's own decisions — and
      binding a catalogue to a channel narrows that channel to the catalogue's
      assortment, so an empty one would hide the catalogue rather than price it.
    DESC
    task install_channels: :environment do
      created = 0
      existing = 0

      Spree::Store.find_each do |store|
        locale = store.preferred_admin_locale.presence || I18n.locale

        SpreePriceContexts::CONTEXTS.each do |code, name_key|
          if store.channels.exists?(code: code)
            existing += 1
            next
          end

          name = Spree.t(name_key, locale: locale)
          store.channels.create!(code: code, name: name)
          created += 1
          puts "  #{store.name}: created channel #{code} (#{name})"
        end
      end

      puts "Done. #{created} created, #{existing} already there."
    end
  end
end
