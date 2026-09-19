# frozen_string_literal: true

# The storefront's flash-sale reads and the ticket claim, wired through Spree's
# extension hook so nothing in core's routes file changes. The controllers
# inherit the Store API's base, so publishable-key auth, the guest gate and the
# error shape behave exactly like core resources.
#
# It lives in config/ rather than lib/ because this is the file Rails watches
# and re-loads: a routes reload re-draws the engine's routes, and a block
# registered once at boot from lib/ is not registered again, so every endpoint
# here would vanish from a running development server until it restarted.
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        resources :flash_sales, only: [:index, :show], id: /.+/ do
          collection do
            # The same activity asked the other way round — by the goods the buy
            # popup is about.
            get 'by_product/:product_id', to: 'flash_sales#by_product', as: :by_product
          end
        end

        # Claiming is a customer's, and so is reading back what they hold.
        resources :flash_sale_tickets, only: [:create]

        namespace :customer, path: 'customers/me' do
          resources :flash_sale_tickets, only: [:index]
        end

        # One wait per customer per stretch, so both verbs name the same
        # collection the plan's contract does.
        post 'flash_sale_slots/:flash_sale_slot_id/reminders',
             to: 'flash_sale_slots/reminders#create', as: :flash_sale_slot_reminders
        delete 'flash_sale_slots/:flash_sale_slot_id/reminders',
               to: 'flash_sale_slots/reminders#destroy'
      end
    end
  end
end
