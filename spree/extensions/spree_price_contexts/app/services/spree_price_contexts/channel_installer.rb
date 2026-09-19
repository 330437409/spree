module SpreePriceContexts
  # Gives a store the three price-context channels, and nothing to a store that
  # already has them.
  #
  # A channel that is there is left exactly as it is, name included, so an
  # operator's rename survives a re-run. What this does not do is bind a
  # catalogue: that narrows the channel to the catalogue's assortment, which is
  # a pricing decision rather than setup.
  class ChannelInstaller
    # @param store [Spree::Store]
    # @return [Hash{Symbol => Array<String>}] the codes created and the codes
    #   that were already there
    def self.call(store:)
      new(store: store).call
    end

    def initialize(store:)
      @store = store
    end

    def call
      created = []
      existing = []

      SpreePriceContexts::CONTEXTS.each do |code, name_key|
        if @store.channels.exists?(code: code)
          existing << code
          next
        end

        @store.channels.create!(code: code, name: name_for(name_key))
        created << code
      end

      { created: created, existing: existing }
    end

    private

    # A store administered in a locale this gem ships no file for answers from
    # the application's default rather than naming a channel "translation
    # missing", which is what a missing translation returns instead of raising.
    def name_for(name_key)
      locale = @store.preferred_admin_locale.presence || I18n.locale

      return Spree.t(name_key, locale: locale) if I18n.exists?(name_key, locale: locale, scope: :spree)

      Spree.t(name_key, locale: I18n.default_locale)
    end
  end
end
