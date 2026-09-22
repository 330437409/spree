require 'rails/generators'

module SpreeScenarioPurchases
  module Generators
    # Copies this gem's one table into the host app.
    #
    # The gem brings its own migration rather than landing its table in core:
    # what is bought and in which channel is this frame's, where the payment
    # rows it settles through are core's
    # (docs/plans/6.1-scenario-purchases.md).
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_scenario_purchases'
      end

      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
