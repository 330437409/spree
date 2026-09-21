module Spree
  module Api
    module V3
      # Store API Customer Serializer
      # Customer-facing user data
      class CustomerSerializer < BaseSerializer
        typelize email: :string, first_name: [:string, nullable: true], last_name: [:string, nullable: true],
                 full_name: :string,
                 phone: [:string, nullable: true], accepts_email_marketing: :boolean,
                 nickname: [:string, nullable: true], city: [:string, nullable: true],
                 gender: [:string, nullable: true, enum: Spree::Customer::GENDERS],
                 birthday: [:string, nullable: true],
                 avatar_url: [:string, nullable: true],
                 orders_count: :number,
                 available_store_credit_total: :string, display_available_store_credit_total: :string,
                 default_billing_address: { nullable: true }, default_shipping_address: { nullable: true },
                 newsletter_subscriber: { nullable: true },
                 email_marketing_consent_updated_at: [:string, nullable: true]

        attributes :email, :first_name, :last_name, :phone, :accepts_email_marketing,
                   :nickname, :gender, :city

        # When the opt-in last moved. Customer-facing because a person asking
        # "when did I agree to this?" is exercising a right, not reading
        # operational data.
        attribute :email_marketing_consent_updated_at do |user|
          user.email_marketing_consent_updated_at&.iso8601
        end

        # A storefront profiles by date, not by instant: the timezone the
        # customer was born in is not a thing this store knows.
        attribute :birthday do |user|
          user.birthday&.iso8601
        end

        # An ActiveStorage attachment, so the URL is the app's own and may
        # change — a client stores what it was handed rather than an id.
        attribute :avatar_url do |user|
          image_url_for(user.avatar)
        end

        # Whether this customer has bought here yet, which the storefront
        # branches on: a first-time buyer sees first-order offers where a
        # regular sees what they usually buy (docs/plans/6.1-store-api-miniprogram-gaps.md).
        # Scoped to the request's store — a customer of a sibling store is
        # still new here.
        attribute :orders_count do |user, params|
          store = params&.dig(:store) || Spree::Current.store
          store ? user.orders.for_store(store).complete.count : user.orders.complete.count
        end

        attribute :full_name do |user|
          user.full_name.presence || user.email
        end

        attribute :available_store_credit_total do |user, params|
          store = params&.dig(:store) || Spree::Current.store
          currency = params&.dig(:currency) || Spree::Current.currency || store&.default_currency
          user.total_available_store_credit(currency, store).to_s
        end

        attribute :display_available_store_credit_total do |user, params|
          store = params&.dig(:store) || Spree::Current.store
          currency = params&.dig(:currency) || Spree::Current.currency || store&.default_currency
          Spree::Money.new(user.total_available_store_credit(currency, store), currency: currency).to_s
        end

        many :addresses, resource: proc { Spree.api.address_serializer }
        one :bill_address, key: :default_billing_address, resource: proc { Spree.api.address_serializer }
        one :ship_address, key: :default_shipping_address, resource: proc { Spree.api.address_serializer }

        one :newsletter_subscriber, resource: proc { Spree.api.newsletter_subscriber_serializer } do |user, params|
          store = params&.dig(:store) || Spree::Current.store
          user.newsletter_subscriber(store)
        end

        # Membership signal for storefront branching (e.g. wholesale approval);
        # scoped to the request store (params first — Spree::Current.store falls
        # back to the DEFAULT store, wrong on sibling stores' domains) so other
        # stores' memberships never leak.
        many :customer_groups,
             proc { |groups, params| groups.for_store(params&.dig(:store) || Spree::Current.store) },
             resource: proc { Spree.api.customer_group_serializer }
      end
    end
  end
end
