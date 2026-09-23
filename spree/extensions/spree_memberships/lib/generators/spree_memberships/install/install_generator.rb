require 'rails/generators'

module SpreeMemberships
  module Generators
    # Copies this gem's two tables into the host app.
    #
    # The gem brings its own migrations rather than landing its tables in core:
    # what a tier carries and what it grants are the membership programme's,
    # where the customer group they hang from is core's
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      # Four gems' tables come along: a card records the scenario order that
      # issued it, and entering a tier hands over points and a coupon, which the
      # ledger and the wallet own.
      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_memberships,spree_scenario_purchases,spree_points,spree_coupon_wallet'
      end

      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
