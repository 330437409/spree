# frozen_string_literal: true

# Wired through Spree's extension hook so the endpoints are served under
# /api/v3/ without touching any core routes file, and drawn here rather than in
# lib/ because this is the file Rails watches and re-loads — a block registered
# once at boot from lib/ is not registered again, so these endpoints would
# vanish from a running development server until it restarted
# (docs/plans/6.1-phone-verification-and-payment-pin.md).
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # Sending and checking are both creations: asking for a code creates
        # one, and verifying one creates a check whose creation either succeeds
        # or fails. Neither is an action on a resource, which is what the
        # repository asks for instead of `POST .../verify`.
        resources :verification_codes, only: [:create]
        resources :verification_checks, only: [:create]

        # The customer's own payment PIN: one row, read, written, switched and
        # closed. `update` serves both PUT (set or change) and PATCH (the
        # required switch), which is the shape the resource has.
        resource :payment_pin, only: [:show, :update, :destroy]
      end

      namespace :admin do
        # Support unlocking a customer who has locked themselves out. An
        # operator's route rather than the customer's, because a lockout with
        # no way out is a support hole rather than a security control.
        resources :customers, only: [] do
          # The controller is named explicitly, as every nested singular
          # resource in v3 is: Rails derives `admin/payment_pins` otherwise.
          resource :payment_pin, only: [:destroy], controller: 'customers/payment_pins'
        end
      end
    end
  end
end
