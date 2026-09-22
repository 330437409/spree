require 'rails/engine'

module SpreeMemberships
  class Engine < Rails::Engine
    engine_name 'spree_memberships'

    # `to_prepare` rather than `after_initialize`: the registry is a plain array
    # and would survive a reload, but a reload redefines the right classes
    # themselves, and re-registering keeps the two in step.
    config.to_prepare do
      # A scope of the gem's own, in the loyalty group beside gift cards and
      # store credits: CanCanCan has a rule for exactly the models a declared
      # scope names, so without this a staff role holding the customer keys is
      # refused every tier and rights write — and the picker too.
      Spree.permissions.register_scope(:memberships, group: :loyalty, resources: -> {
        [Spree::MembershipTierSetting, Spree::MembershipRight]
      })

      [
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
      ].each do |kind|
        # By name rather than by identity: a reload redefines these constants,
        # and an identity check would register each reloaded kind beside its
        # stale twin until the picker lists every kind once per edit.
        SpreeMemberships.membership_rights.reject! { |registered| registered.name == kind.name }
        SpreeMemberships.membership_rights << kind
      end
    end
  end
end
