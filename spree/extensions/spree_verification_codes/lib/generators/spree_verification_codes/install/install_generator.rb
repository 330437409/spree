require 'rails/generators'

module SpreeVerificationCodes
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      # A code is sent through the platform's one sender, so a host installing
      # this gem needs that one too.
      def install_notifications
        generate 'spree_notifications:install'
      end

      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_verification_codes'
      end

      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
