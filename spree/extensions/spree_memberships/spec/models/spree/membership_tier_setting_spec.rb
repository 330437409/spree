require 'spec_helper'

RSpec.describe Spree::MembershipTierSetting, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:tier) { create(:membership_tier_setting, customer_group: group) }

  it 'reaches its store through the group it hangs from' do
    expect(tier.store).to eq(store)
    expect(tier.name).to eq(group.name)
  end

  # What the buy page's savings popup renders: four rows of the operator's copy,
  # in the order the client's icons are in, and nothing worked out.
  describe 'what it says a member saves' do
    it 'answers four rows in the client’s own order' do
      tier.update!(preferences: { saving_order_title: '下单立省', saving_order_content: '会员价再低一点',
                                  saving_gift_title: '开卡送酒', saving_gift_content: '首月送一瓶' })

      expect(tier.reload.saving_rows).to eq([
        { 'title' => '下单立省', 'content' => '会员价再低一点' },
        { 'title' => '', 'content' => '' },
        { 'title' => '', 'content' => '' },
        { 'title' => '开卡送酒', 'content' => '首月送一瓶' }
      ])
    end

    # A row nobody wrote stays in the list rather than being dropped: the client
    # places its icons by position, so a shorter list would shift them.
    it 'answers blanks for a tier nobody has written for' do
      expect(tier.saving_rows.length).to eq(4)
      expect(tier.saving_rows.map(&:values).flatten).to all(be_blank)
      expect(tier.saving_month_amount).to be_nil
    end

    # Plain decimal notation, because `BigDecimal#to_s` renders 0.06 as "0.6e-1"
    # — not a number to print beside a currency sign.
    it 'answers the monthly figure in the notation the rest of the API uses' do
      { '0.06' => '0.06', 12.5 => '12.5', '12.50' => '12.5', 0 => '0.0' }.each do |written, answered|
        tier.update!(preferences: { saving_month_amount: written })

        expect(tier.reload.saving_month_amount).to eq(answered)
      end
    end

    # The whole popup renders through this reader, so a value nobody can make
    # sense of is answered nil rather than raised over.
    it 'answers nothing for a figure that cannot be read as a number' do
      tier.update_columns(preferences: { saving_month_amount: 'abc' })

      expect(tier.reload.saving_month_amount).to be_nil
    end

    # A wholesale preferences write skips the typecast each preference's own
    # writer does, so the shape is checked where the operator writes it: a title
    # that is an object and a figure that is not a number both break the read
    # that renders them.
    it 'refuses copy that is not text and a figure that is not a number' do
      tier.preferences = { saving_order_title: { nested: 'yes' } }
      expect(tier).not_to be_valid

      tier.preferences = { saving_coupon_title: 42 }
      expect(tier).not_to be_valid

      tier.preferences = { saving_month_amount: 'abc' }
      expect(tier).not_to be_valid

      tier.preferences = { saving_month_amount: '12.50', saving_order_title: '下单立省' }
      expect(tier).to be_valid
    end
  end

  # One row per group is what makes a group a tier rather than an audience.
  it 'belongs to a group once' do
    tier

    expect(build(:membership_tier_setting, customer_group: group)).not_to be_valid
  end

  # Among live rows only: a retired settings row is history, and a fresh one for
  # the same group is saved after it is retired.
  it 'lets a group become a tier again once the old row is retired' do
    tier.destroy

    expect(build(:membership_tier_setting, customer_group: group)).to be_valid
  end

  it 'needs a rank, and a term of positive days when it has one' do
    expect(build(:membership_tier_setting, customer_group: group, rank: nil)).not_to be_valid

    other = create(:customer_group, store: store)
    expect(build(:membership_tier_setting, customer_group: other, validity_days: 0)).not_to be_valid
  end

  it 'orders itself the way the client reads a ladder' do
    lower = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1)
    higher = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)

    expect(described_class.ordered.to_a).to eq([lower, higher])
    expect(described_class.for_store(store)).to contain_exactly(lower, higher)
  end

  # A tier nobody qualifies for by spending is one the operator sells or grants,
  # and a zero would say "everybody qualifies".
  it 'qualifies a customer only where it has a threshold' do
    expect(tier.qualifies?(100)).to be(true)
    expect(tier.qualifies?(99)).to be(false)

    tier.update!(threshold: nil)
    expect(tier.qualifies?(1_000)).to be(false)
  end

  # The member price is a catalogue the tier owns and an owned list inside it;
  # the tier row holds the link and answers what the price is.
  describe 'the member price' do
    it 'stands a catalogue up and reports the percentage' do
      tier.update!(member_discount_percentage: 10)

      expect(tier.reload.catalog).to be_present
      expect(tier.member_discount_percentage).to eq(10)
    end

    it 'moves the price without standing up a second catalogue' do
      tier.update!(member_discount_percentage: 10)
      catalog = tier.catalog

      tier.update!(member_discount_percentage: 20)

      expect(tier.reload.catalog_id).to eq(catalog.id)
      expect(tier.member_discount_percentage).to eq(20)
    end

    it 'reports none while the tier grants none' do
      expect(tier.member_discount_percentage).to be_nil
    end

    it 'takes the price out of effect on zero, and reports none' do
      tier.update!(member_discount_percentage: 10)
      tier.update!(member_discount_percentage: 0)

      expect(tier.reload.member_discount_percentage).to be_nil
      expect(tier.catalog).not_to be_active
    end

    # A retired tier leaves its members the group they were in, so a catalogue
    # left in effect would outlive the promise that set it up.
    it 'stops pricing when the tier is retired' do
      tier.update!(member_discount_percentage: 10)
      catalog = tier.catalog

      tier.destroy

      expect(catalog.reload).not_to be_active
    end
  end
end
