module Spree
  module Authentication
    # Signs a provider profile in, or says which rule stopped it.
    #
    # Three rules, in order (docs/plans/6.0-social-login.md):
    #   1. a known identity logs in;
    #   2. an account whose address the provider verified is adopted;
    #   3. anything else needs an account — created through
    #      +Spree.customer_create_workflow+, so registration policy, consent
    #      and the password-less account mode all apply to social sign-up too.
    #
    # A profile with no email stops before rule 3 and answers
    # +registration_required+: creating the account with a placeholder address
    # leaves the shopper unable to ever repair it.
    class ResolveAccount
      # @param profile [Spree::Authentication::Profile]
      # @param store [Spree::Store] the store whose registration this is
      # @param user_class [Class, nil] defaults to +Spree.customer_class+
      # @param trust_unverified_email [Boolean] the integration's opt-in
      def initialize(profile:, store:, user_class: nil, trust_unverified_email: false)
        @profile = profile
        @store = store
        @user_class = user_class || Spree.customer_class
        @trust_unverified_email = trust_unverified_email
      end

      # @return [Spree::Authentication::Resolution]
      def call
        raise ArgumentError, 'A store is required to resolve a social account' if @store.blank?

        identity = Spree::UserIdentity.find_for(provider: @profile.provider, uid: @profile.uid, user_class: @user_class)
        return Resolution.authenticated(Spree::UserIdentity.refresh_from(identity, @profile).user) if identity

        linkable = linkable_user
        return Resolution.authenticated(Spree::UserIdentity.attach_to(linkable, @profile).user) if linkable

        # Staff accounts are invited, never provisioned by a provider — the
        # rule the admin OIDC callback already enforces.
        return Resolution.account_not_provisioned(@profile) unless @user_class == Spree.customer_class

        return Resolution.registration_required(@profile) if @profile.email.blank?

        RegisterAccount.new(profile: @profile, store: @store, user_class: @user_class).call
      end

      private

      # Only a claim the provider marked verified may adopt an account.
      # Matching on an unverified address is how a shopper claims somebody
      # else's. Case-insensitive because Spree normalises email by squishing
      # only, so "Ada@Example.com" is the same account as "ada@example.com".
      #
      # @return [Object, nil]
      def linkable_user
        email = @profile.verified_email(trust_unverified: @trust_unverified_email)
        return nil if email.blank?

        @user_class.where(@user_class.arel_table[:email].lower.eq(email.downcase)).first
      end
    end
  end
end
