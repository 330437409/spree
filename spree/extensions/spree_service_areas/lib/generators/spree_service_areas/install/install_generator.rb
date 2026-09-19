require 'rails/generators'

module SpreeServiceAreas
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      # The tree is this gem's other half — a binding names a division and a
      # vendor's code is mapped to one — so a host that installs this gem needs
      # that table as well, and gets both from one command.
      def install_administrative_divisions
        generate 'spree_administrative_divisions:install'
      end

      def copy_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_service_areas'
      end


      def run_migrations
        return unless options[:auto_run_migrations]

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
