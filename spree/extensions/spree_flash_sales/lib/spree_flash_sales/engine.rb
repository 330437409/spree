require 'rails/engine'

module SpreeFlashSales
  class Engine < Rails::Engine
    engine_name 'spree_flash_sales'

    # The price preview asks this for a line whose request names an activity:
    # the activity's price, and the verdicts that come with it. Registered after
    # initialization because core assigns the registry in its own initializer,
    # and engine callbacks run in load order.
    config.after_initialize do
      source = SpreeFlashSales::PricePreviewSource
      Spree.price_preview_sources << source unless Spree.price_preview_sources.include?(source)
    end
  end
end
