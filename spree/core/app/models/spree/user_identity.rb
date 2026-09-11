module Spree
  class UserIdentity < Spree::Base
    has_prefix_id :uid

    belongs_to :user, polymorphic: true, optional: false

    # Provider tokens are credentials to the shopper's profile — a WeChat
    # refresh token lives 30 days — so they get the same treatment the
    # codebase already gives comparable secrets (Spree::WebhookEndpoint,
    # Spree::GatewayCustomer).
    encrypts :access_token, :refresh_token if Rails.configuration.active_record.encryption.include?(:primary_key)

    validates :provider, presence: true
    validates :uid, presence: true, uniqueness: { scope: %i[provider user_type] }

    validates :provider, inclusion: {
      in: lambda { |_record|
        (Spree.store_authentication_strategies.keys + Spree.admin_authentication_strategies.keys).uniq.map(&:to_s)
      }
    }

    class << self
      # @param provider [String, Symbol]
      # @param uid [String]
      # @param user_class [Class, nil] defaults to +Spree.customer_class+
      # @return [Spree::UserIdentity, nil]
      def find_for(provider:, uid:, user_class: nil)
        find_by(
          provider: provider.to_s,
          uid: uid.to_s,
          user_type: (user_class || Spree.customer_class).name
        )
      end

      # Records a provider profile against an account that already exists.
      #
      # Under a concurrent first login the unique index — and the uniqueness
      # validation in front of it — picks the winner, and the loser re-reads
      # it, so both requests end on one identity.
      #
      # @param user [Object] a customer or admin user
      # @param profile [Spree::Authentication::Profile]
      # @return [Spree::UserIdentity]
      def attach_to(user, profile)
        identity = user.identities.find_or_initialize_by(provider: profile.provider.to_s, uid: profile.uid.to_s)
        identity.apply_profile(profile)
        identity.save!
        identity
      rescue ActiveRecord::RecordNotUnique
        find_for(provider: profile.provider, uid: profile.uid, user_class: user.class)
      rescue ActiveRecord::RecordInvalid => e
        winner = find_for(provider: profile.provider, uid: profile.uid, user_class: user.class)
        raise e if winner.nil?

        winner
      end

      # Refreshes the stored profile and tokens. A provider that returns no
      # token on this call must not blank the stored one.
      #
      # @param identity [Spree::UserIdentity]
      # @param profile [Spree::Authentication::Profile]
      # @return [Spree::UserIdentity]
      def refresh_from(identity, profile)
        identity.apply_profile(profile)
        identity.save! if identity.changed?
        identity
      end

      # Signs an OAuth profile in, creating the account through the
      # registration workflow when one is needed.
      #
      # @return [Object] the customer
      # @raise [Spree::Authentication::RegistrationRequired] when the profile
      #   carries no email — the caller must collect one through the
      #   registration step instead of inventing an address
      # @raise [ActiveRecord::RecordInvalid] when the workflow rejected the
      #   registration (a taken address included)
      def find_or_create_from_oauth(provider:, uid:, info:, tokens: {}, user_class: nil, store: nil, email_verified: nil)
        user_class ||= Spree.customer_class
        profile = Spree::Authentication::Profile.new(
          provider: provider,
          uid: uid,
          info: info,
          tokens: tokens,
          email: info[:email] || info['email'],
          email_verified: email_verified.nil? ? (info[:email_verified] || info['email_verified']) : email_verified
        )

        # Staff accounts are outside the storefront registration flow, and the
        # only caller is a strategy the merchant wrote and trusts. They keep the
        # account-creation behaviour those strategies already rely on.
        return create_staff_account(user_class, profile) unless user_class == Spree.customer_class

        resolution = Spree::Authentication::ResolveAccount.new(
          profile: profile,
          store: store || Spree::Current.store,
          user_class: user_class
        ).call

        return resolution.user if resolution.authenticated?
        raise Spree::Authentication::RegistrationRequired if resolution.registration_required?

        raise ActiveRecord::RecordInvalid.new(resolution.record)
      end

      # @deprecated Use {.refresh_from} with a Spree::Authentication::Profile; removed in 6.1.
      def refresh_identity(identity, info:, tokens: {})
        Spree::Deprecation.warn(
          'Spree::UserIdentity.refresh_identity is deprecated and will be removed in Spree 6.1. ' \
          'Use Spree::UserIdentity.refresh_from with a Spree::Authentication::Profile.'
        )

        refresh_from(
          identity,
          Spree::Authentication::Profile.new(provider: identity.provider, uid: identity.uid, info: info, tokens: tokens)
        )
      end

      private

      # A strategy the merchant wrote for staff accounts is a trusted
      # integration, so it keeps creating its own account: registration policy,
      # consent and password reset belong to the storefront flow it is not part
      # of.
      def create_staff_account(user_class, profile)
        identity = find_for(provider: profile.provider, uid: profile.uid, user_class: user_class)
        return refresh_from(identity, profile).user if identity

        transaction do
          user = user_class.create!(
            email: profile.email.presence || generate_temp_email(profile.provider, profile.uid),
            password: SecureRandom.hex(32),
            first_name: profile.info[:first_name] || profile.info['first_name'],
            last_name: profile.info[:last_name] || profile.info['last_name']
          )
          attach_to(user, profile)
          user
        end
      rescue ActiveRecord::RecordNotUnique
        find_for(provider: profile.provider, uid: profile.uid, user_class: user_class).user
      end

      def generate_temp_email(provider, uid)
        "#{provider}-#{uid}@temporary.example.com"
      end
    end

    # Copies a provider profile onto this identity. Absent tokens leave the
    # stored ones alone; a provider that does not refresh them must not clear them.
    #
    # @param profile [Spree::Authentication::Profile]
    # @return [Spree::UserIdentity]
    def apply_profile(profile)
      self.info = profile.info if profile.info.present?
      self.access_token = profile.token(:access_token) if profile.token?(:access_token)
      self.refresh_token = profile.token(:refresh_token) if profile.token?(:refresh_token)
      self.expires_at = profile.token(:expires_at) if profile.token?(:expires_at)
      self
    end

    def expired?
      expires_at && expires_at < Time.current
    end
  end
end
