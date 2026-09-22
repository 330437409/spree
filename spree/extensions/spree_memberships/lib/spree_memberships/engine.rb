require 'rails/engine'

module SpreeMemberships
  class Engine < Rails::Engine
    engine_name 'spree_memberships'

    # `to_prepare` rather than `after_initialize`: the registry is a plain array
    # and would survive a reload, but a reload redefines the right classes
    # themselves, and re-registering keeps the two in step.
    config.to_prepare do
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
        SpreeMemberships.membership_rights << kind unless SpreeMemberships.membership_rights.include?(kind)
      end
    end
  end
end
