require 'spec_helper'

RSpec.describe 'the membership permission scope', type: :model do
  # CanCanCan has a rule for exactly the models a declared scope names, so the
  # gem registers one: without it a staff role holding the customer keys is
  # refused every tier and rights write, and the picker with them.
  it 'declares the gem\'s models under the loyalty group' do
    expect(Spree.permissions.scope_for_resource(Spree::MembershipRight)&.name).to eq(:memberships)
    expect(Spree.permissions.scope_for_resource(Spree::MembershipTierSetting)&.name).to eq(:memberships)

    scope = Spree.permissions.scopes.find { |candidate| candidate.name == :memberships }
    expect(scope.group).to eq(:loyalty)
  end

  it 'registers each kind once, however often the registry is filled' do
    names = SpreeMemberships.membership_rights.map(&:name)

    expect(names).to eq(names.uniq)
    expect(names.size).to eq(10)
  end
end
