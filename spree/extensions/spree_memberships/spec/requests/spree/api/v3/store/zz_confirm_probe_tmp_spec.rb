require 'spec_helper'

# TEMPORARY PROBE — delete before finishing.
RSpec.describe 'PROBE confirm', type: :request do
  include_context 'API v3 Store authenticated'

  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1) }

  def adjustment_promotion(amount)
    promotion = create(:promotion, store: store, name: "probe-#{amount}")
    calculator = Spree::Calculator::FlatRate.new
    calculator.preferred_amount = amount
    Spree::Promotion::Actions::CreateAdjustment.create!(promotion: promotion, calculator: calculator)
    promotion
  end

  def build_right(promotion)
    create(:surprise_right, customer_group: group, published: true,
                            preferences: { surprise_coupons: [{ 'promotion_id' => promotion.prefixed_id, 'self_use' => 1, 'friend_use' => 0 }] })
  end

  it 'PROBE: rename then retire, three times' do
    3.times do |round|
      promotion = adjustment_promotion(30)
      right = build_right(promotion)
      pid = right.id

      fresh = Spree::MembershipRight.find(pid)
      fresh.name = 'renamed'
      puts "PROBE r#{round} rename save => #{fresh.save} #{fresh.errors.full_messages.inspect}"

      destroyed = promotion.destroy
      puts "PROBE r#{round} destroy => #{destroyed.inspect[0, 30]} still_there=#{Spree::Promotion.unscoped.exists?(id: promotion.id)}"

      again = Spree::MembershipRight.find(pid)
      again.published = false
      puts "PROBE r#{round} guard => #{again.will_save_change_to_preferences?} retire save => #{again.save} #{again.errors.full_messages.inspect}"
    end
  end

  it 'PROBE: retire without a prior rename' do
    promotion = adjustment_promotion(30)
    right = build_right(promotion)
    pid = right.id
    promotion.destroy
    again = Spree::MembershipRight.find(pid)
    again.published = false
    puts "PROBE plain retire guard => #{again.will_save_change_to_preferences?} save => #{again.save} #{again.errors.full_messages.inspect}"
  end

  it 'PROBE: retire a right whose promotion was never referenced by it' do
    promotion = adjustment_promotion(30)
    right = build_right(promotion)
    pid = right.id
    other = adjustment_promotion(50)
    other.destroy
    again = Spree::MembershipRight.find(pid)
    again.published = false
    puts "PROBE unrelated delete guard => #{again.will_save_change_to_preferences?} save => #{again.save} #{again.errors.full_messages.inspect}"
  end
end
