require 'spree_core'
require 'spree_memberships/engine'

# What a tier grants, and what a tier is.
#
# A tier is not a table of its own: it is a `Spree::CustomerGroup` — the audience
# model this repository already has — plus one `Spree::MembershipTierSetting` row
# that carries its rank and its threshold, and whose existence is what makes a
# group a tier. What that tier grants are its rights, and a right is a registered
# class rather than an enum value, so a kind a gem adds needs no column and no
# change to any read (docs/plans/6.1-membership-tiers-and-rights.md).
module SpreeMemberships
  # The kinds of right a tier may carry, each a subclass of
  # `Spree::MembershipRight` declaring its own settings and the member-centre
  # panel it presents in. A registry rather than a constant list, so the ten the
  # client switches on are the built-ins rather than a closed set.
  #
  # Lives here rather than as another key in core's `Environment`, following the
  # points shop and the coupon wallet: only a membership has rights.
  def self.membership_rights
    @membership_rights ||= []
  end
end
