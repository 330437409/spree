require 'spec_helper'

RSpec.describe Spree::Memberships::MemberDay, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }

  def day(preferences)
    right = build(:svip_date_right, customer_group: group, preferences: preferences)

    described_class.new(right: right, store: store)
  end

  it 'renders the day in words from the weekday, not from the operator’s copy' do
    expect(day(weekday: 'wednesday').line).to eq('Every Wednesday')

    moved = day(weekday: 'thursday', day_name: 'Wednesday VIP day')

    expect(moved.line).to eq('Every Thursday')
    expect(moved.day_name).to eq('Wednesday VIP day')
  end

  # The page prints this beside 惊喜享不停, so it is the customer's language rather
  # than the server's.
  it 'renders the day in the language it is read in' do
    I18n.with_locale(:'zh-CN') do
      expect(day(weekday: 'wednesday').line).to eq('每周三')
    end
  end

  # A weekday nobody declares is no day to print: the page answers nothing rather
  # than the markup a translation library renders for a key that is not there.
  it 'answers no words for a weekday nobody declares' do
    right = build(:svip_date_right, customer_group: group)
    right.preferences = { weekday: 'funday' }

    expect(described_class.new(right: right, store: store).line).to be_nil
  end

  it 'is today when the store’s own calendar says so' do
    store.update!(preferred_timezone: 'Asia/Shanghai')
    # A Wednesday in Shanghai, which is still Tuesday in UTC.
    Timecop.freeze(Time.utc(2026, 9, 23, 2, 0)) do
      expect(day(weekday: 'wednesday').today?).to be(true)
      expect(day(weekday: 'tuesday').today?).to be(false)
    end
  end

  it 'carries what the day earns and what the basket has to reach' do
    member_day = day(multiplier: 3, minimum_amount: '199.5', qualifying_kinds: ['SVIP超级会员', ''])

    expect(member_day.times).to eq(3)
    expect(member_day.minimum_amount).to eq(BigDecimal('199.5'))
    expect(member_day.qualifying_kinds).to eq(['SVIP超级会员'])
  end

  it 'says whether the day hands a red packet over' do
    expect(day({}).rights_red?).to be(false)
    expect(day(rights_red_money: '20').rights_red?).to be(true)
    expect(day(rights_red_money: '20').rights_red_money).to eq(BigDecimal('20'))
  end

  it 'carries the copy the operator wrote around it' do
    member_day = day(rules: '会员日规则', share_title: '超级会员日', share_icon: 'https://cdn.example.com/day.png')

    expect(member_day.rule).to eq('会员日规则')
    expect(member_day.share_title).to eq('超级会员日')
    expect(member_day.share_icon).to eq('https://cdn.example.com/day.png')
  end

  it 'answers nothing for copy nobody wrote' do
    member_day = day({})

    expect(member_day.day_name).to be_nil
    expect(member_day.rule).to be_nil
    expect(member_day.share_title).to be_nil
    expect(member_day.share_icon).to be_nil
  end
end
