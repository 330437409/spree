# frozen_string_literal: true

require 'rails/generators'

module SpreeProductBundles
  module Generators
    # Installs the extension into a host application: copies its migrations
    # through Rails' own engine-migration task, and runs them when asked to.
    #
    # `rake test_app` requires this file by name and invokes it with
    # `--auto-run-migrations`, which is why the option exists rather than being
    # left to a `db:migrate` run by hand — a table whose migration was copied
    # but never run is a table every spec then fails to find.
    class InstallGenerator < Rails::Generators::Base
      desc 'Installs spree_product_bundles and runs its migrations.'

      class_option :auto_run_migrations, type: :boolean, default: false,
                                         desc: 'Run db:migrate after copying the migrations'

      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_product_bundles'
      end

      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
