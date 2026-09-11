module Spree
  module Authentication
    # Creates the account a provider profile belongs to, then attaches the
    # identity to it.
    #
    # Account creation goes through +Spree.customer_create_workflow+ — the one
    # registration flow core documents — so a shop's registration policy
    # (+validate+ hook), consent recording, newsletter linking and the
    # password-less account mode apply exactly as they do to form
    # registration. The account is password-less: the shopper authenticated
    # with the provider, and claims a password later through password reset.
    class RegisterAccount
      # @param profile [Spree::Authentication::Profile]
      # @param store [Spree::Store]
      # @param user_class [Class, nil] defaults to +Spree.customer_class+
      def initialize(profile:, store:, user_class: nil)
        @profile = profile
        @store = store
        @user_class = user_class || Spree.customer_class
      end

      # @param email [String] the address the shopper supplied, or the one the
      #   provider returned
      # @param first_name [String, nil] overrides the provider's claim
      # @param last_name [String, nil] overrides the provider's claim
      # @param terms_of_service [Boolean, nil] whether the shopper ticked the box
      # @return [Spree::Authentication::Resolution]
      def call(email: @profile.email, first_name: nil, last_name: nil, terms_of_service: nil,
               ip_address: nil, user_agent: nil)
        result = Spree.customer_create_workflow.call(
          store: @store,
          email: email,
          first_name: first_name.presence || info_value(:first_name),
          last_name: last_name.presence || info_value(:last_name),
          password_required: false,
          terms_of_service: terms_of_service,
          ip_address: ip_address,
          user_agent: user_agent
        )

        return Resolution.authenticated(Spree::UserIdentity.attach_to(result.value, @profile).user) if result.success?

        resolution_for_failure(result)
      end

      private

      # A refused registration either carries the unsaved customer — a
      # validation failure the form can show — or only the workflow's own
      # errors, which is how a registration policy rejects a sign-up before a
      # customer exists. Both are the shopper's to act on; neither is a 500.
      def resolution_for_failure(result)
        customer = result.value
        return Resolution.invalid(nil, @profile, message: result.error.to_s) if customer.blank?

        return Resolution.email_taken(customer, @profile) if customer.errors.of_kind?(:email, :taken)

        Resolution.invalid(customer, @profile)
      end

      def info_value(key)
        @profile.info[key] || @profile.info[key.to_s]
      end
    end
  end
end
