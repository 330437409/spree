# A tier of this store, beside the one an example is about — what "the customer
# already holds a term of somebody else's tier" is built from. Its rank is the
# factory's sequence: nothing an example asserts turns on it, so naming one
# would read as though it did.
module MembershipTierHelpers
  # @return [Spree::MembershipTierSetting]
  def another_tier
    create(:membership_tier_setting, customer_group: create(:customer_group, store: store))
  end
end

RSpec.configure do |config|
  config.include MembershipTierHelpers
end
