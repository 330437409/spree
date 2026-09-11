module Spree
  module Authentication
    # The answer to "who is this person, and can we sign them in?" — either an
    # authenticated account, or a profile that still needs an email before one
    # can exist.
    class Resolution
      include ActiveModel::Model
      include ActiveModel::Attributes

      STATUSES = %w[authenticated registration_required email_taken invalid account_not_provisioned].freeze

      attribute :status, :string

      # The account, when +authenticated?+.
      attr_accessor :user
      # The provider profile, carried so a caller can mint a registration token.
      attr_accessor :profile
      # The unsaved customer behind +email_taken?+ / +invalid?+.
      attr_accessor :record

      validate :status_is_known

      # @return [Spree::Authentication::Resolution]
      def self.authenticated(user)
        new(status: 'authenticated', user: user)
      end

      # @return [Spree::Authentication::Resolution]
      def self.registration_required(profile)
        new(status: 'registration_required', profile: profile)
      end

      # @return [Spree::Authentication::Resolution]
      def self.email_taken(record, profile)
        new(status: 'email_taken', record: record, profile: profile)
      end

      # @return [Spree::Authentication::Resolution]
      def self.invalid(record, profile)
        new(status: 'invalid', record: record, profile: profile)
      end

      # @return [Spree::Authentication::Resolution]
      def self.account_not_provisioned(profile)
        new(status: 'account_not_provisioned', profile: profile)
      end

      def authenticated?
        status == 'authenticated'
      end

      def registration_required?
        status == 'registration_required'
      end

      def email_taken?
        status == 'email_taken'
      end

      def invalid?
        status == 'invalid'
      end

      def account_not_provisioned?
        status == 'account_not_provisioned'
      end

      # @return [ActiveModel::Errors, nil] the customer's errors, when there are any
      def record_errors
        record&.errors
      end

      private

      def status_is_known
        errors.add(:status, :inclusion) unless STATUSES.include?(status)
      end
    end
  end
end
