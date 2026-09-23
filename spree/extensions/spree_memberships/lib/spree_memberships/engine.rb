require 'rails/engine'

module SpreeMemberships
  class Engine < Rails::Engine
    engine_name 'spree_memberships'

    # Registers kinds of a gem's registries by class *name* rather than by
    # identity: a reload redefines those constants, and an identity check would
    # register each reloaded kind beside its stale twin until the picker lists
    # every kind once per edit.
    def self.register_kinds(registry, kinds)
      kinds.each do |kind|
        registry.reject! { |registered| registered.name == kind.name }
        registry << kind
      end
    end

    # `to_prepare` rather than `after_initialize`: the registries are plain arrays
    # that survive a reload while the classes in them do not, so re-registering
    # keeps the two in step.
    config.to_prepare do
      # A scope of the gem's own, in the loyalty group beside gift cards and
      # store credits: CanCanCan has a rule for exactly the models a declared
      # scope names, so without this a staff role holding the customer keys is
      # refused every tier and rights write — and the picker too.
      Spree.permissions.register_scope(:memberships, group: :loyalty, resources: -> {
        [Spree::MembershipTierSetting, Spree::MembershipRight, Spree::MembershipCard, Spree::Membership]
      })

      SpreeMemberships::Engine.register_kinds(SpreeMemberships.membership_rights, [
        Spree::MembershipRights::MemberPrice,
        Spree::MembershipRights::ExclusiveCoupon,
        Spree::MembershipRights::Coupon,
        Spree::MembershipRights::LargeCoupon,
        Spree::MembershipRights::AddBag,
        Spree::MembershipRights::PriorityDistribution,
        Spree::MembershipRights::BirthdayDoubleIntegral,
        Spree::MembershipRights::GiveGift,
        Spree::MembershipRights::SurpriseRedEnvelope,
        Spree::MembershipRights::SvipDate
      ])

      # The one way to buy a term: the purchase's kind, registered with the
      # scenario-purchase frame the same way the rights are registered here.
      SpreeMemberships::Engine.register_kinds(SpreeScenarioPurchases.scenario_order_kinds,
                                              [Spree::MembershipKinds::Vip])

      # The member price is the platform's promise, so the platform funds it:
      # the earning carries the seller's shortfall against the shelf price as a
      # subsidy beside it. Registered by class name, which is what makes this
      # survive a reload — and `Spree.hooks.validate!` fails the boot if the
      # workflow ever stops declaring the hook.
      Spree.hooks.register('seller_transfers.create.funded_discounts',
                           'Spree::Memberships::FundMemberDiscount')
    end
  end
end
