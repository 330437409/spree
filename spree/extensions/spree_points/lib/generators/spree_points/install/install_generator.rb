require 'rails/generators'

module SpreePoints
  module Generators
    # Copies this gem's five tables into the host app.
    #
    # The gem brings its own migrations rather than landing its tables in core:
    # the account, the lot's side table and the allocation trail are the points
    # programme's, where the grant row and the ledger it writes through are
    # shared (docs/plans/6.1-points-and-growth-value.md).
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_points'
      end

      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
