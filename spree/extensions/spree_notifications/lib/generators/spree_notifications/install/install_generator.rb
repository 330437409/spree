require 'rails/generators'

module SpreeNotifications
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      # Nothing to copy yet: a channel's credentials are a row in
      # spree_integrations, which core ships. The generator exists so a host
      # installs every extension the same way, and so the first migration this
      # gem grows has somewhere to land.
      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_notifications'
      end

      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
