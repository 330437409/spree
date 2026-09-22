require 'rails/generators'

module SpreeCouponWallet
  module Generators
    # Copies this gem's two tables into the host app.
    #
    # The gem brings its own migrations rather than landing its tables in core:
    # the wallet and its campaigns are this domain's, where the grant row they
    # hang from is shared (docs/plans/6.1-coupon-wallet.md).
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_coupon_wallet'
      end

      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
