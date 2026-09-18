require 'rails/engine'

module SpreeAdministrativeDivisions
  class Engine < Rails::Engine
    engine_name 'spree_administrative_divisions'

    # Gem name and module disagree on word boundaries, so Zeitwerk would look
    # for a constant that does not exist without this.
    initializer 'spree_administrative_divisions.inflections', before: :set_autoload_paths do
      Rails.autoloaders.each do |autoloader|
        autoloader.inflector.inflect(
          'spree_administrative_divisions' => 'SpreeAdministrativeDivisions'
        )
      end
    end
  end
end
