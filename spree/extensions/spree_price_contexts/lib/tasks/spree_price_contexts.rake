namespace :spree do
  namespace :price_contexts do
    desc <<~DESC
      Creates the three price-context channels a storefront asks in — 区域, 现场推广 and
      线下 — under every store that does not have them yet:

        bin/rails spree:price_contexts:install_channels

      The channels are created with the codes the client already sends as `cartType`
      (area, scene, offline) and with their names in each store's own admin locale,
      falling back to the application default for a locale this gem ships no file for;
      an operator renames them freely, because the code is what the wire carries.

      It creates the channel and nothing else, and re-running it changes nothing.
      Which catalogue a context prices through, and the price list inside it, are the
      merchant's own decisions — and binding a catalogue to a channel narrows that
      channel to the catalogue's assortment, so an empty one would hide the catalogue
      rather than price it.
    DESC
    task install_channels: :environment do
      created = 0
      existing = 0

      Spree::Store.find_each do |store|
        result = SpreePriceContexts::ChannelInstaller.call(store: store)

        result[:created].each do |code|
          puts "  #{store.name}: created channel #{code} (#{store.channels.find_by(code: code)&.name})"
        end

        created += result[:created].size
        existing += result[:existing].size
      end

      puts "Done. #{created} created, #{existing} already there."
    end
  end
end
