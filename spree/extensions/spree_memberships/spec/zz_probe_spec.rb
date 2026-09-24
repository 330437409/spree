require 'spec_helper'

def say(label, value)
  puts "[PROBE] #{label}: #{value.inspect}"
end

RSpec.describe 'PROBE normalizer', type: :model do
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: create(:store))) }

  it 'normalizes on write, not on read' do
    tier.update_columns(preferences: { 'saving_order_title' => 'Planted' })
    tier.reload
    say 'keys from the DB', tier.preferences.keys.map { |k| [k, k.class] }
    say 'reader for the planted key', tier.preferred_saving_order_title
    say 'saving_rows first row', tier.saving_rows.first
    say 'serialized_preferences title', tier.serialized_preferences['saving_order_title']

    tier.preferred_saving_order_title = 'In place'
    tier.save!
    tier.reload
    say 'after in-place write', tier.preferences
  end

  it 'takes a string-keyed hash on assignment' do
    tier.update!(preferences: { 'saving_order_title' => 'Assigned', 'saving_month_amount' => '3.50' })
    tier.reload
    say 'assigned keys', tier.preferences.keys
    say 'assigned reader', tier.preferred_saving_order_title
    say 'assigned month', tier.preferred_saving_month_amount
    say 'month to_s', tier.preferred_saving_month_amount.to_s
  end

  it 'answers what an ActionController::Parameters becomes' do
    params = ActionController::Parameters.new(
      'saving_order_title' => 'ACP', 'nested_extra' => { 'a' => 'b' },
      'saving_gift_title' => %w[x y]
    )
    say 'permit result class', params.permit(:saving_order_title, nested_extra: {}, saving_gift_title: []).class

    tier.update!(preferences: params)
    tier.reload
    say 'ACP stored', tier.preferences
  end

  it 'reports what a non-hash does' do
    [:dot_h_string, :dot_h_array, :dot_h_integer].each do |probe|
      value = case probe
              when :dot_h_string then 'abc'
              when :dot_h_array then [1, 2]
              else 7
              end
      begin
        say "assign #{probe}", Spree::MembershipTierSetting.normalize_value_for(:preferences, value)
      rescue StandardError => e
        say "assign #{probe} RAISED", "#{e.class}: #{e.message}"
      end
    end

    begin
      tier.preferences = 'abc'
      say 'tier.preferences = "abc"', tier.preferences
    rescue StandardError => e
      say 'tier.preferences = "abc" RAISED', "#{e.class}: #{e.message}"
    end

    begin
      tier.preferences = []
      say 'tier.preferences = []', tier.preferences
    rescue StandardError => e
      say 'tier.preferences = [] RAISED', "#{e.class}: #{e.message}"
    end

    begin
      tier.preferences = nil
      say 'tier.preferences = nil', tier.preferences
    rescue StandardError => e
      say 'tier.preferences = nil RAISED', "#{e.class}: #{e.message}"
    end
  end

  it 'reports the pre-normalizer chain verdict on Parameters' do
    raw = tier.class.columns_hash['preferences'].type
    say 'column type', raw
    chain = Spree::MembershipTierSetting.type_for_attribute('preferences')

    plain = ActiveRecord::Type::Serialized.new(
      ActiveModel::Type::Value.new,
      ActiveRecord::Coders::YAMLColumn.new('preferences', Hash)
    )
    [['parameters', ActionController::Parameters.new('a' => 'b')], ['hash', { 'a' => 'b' }],
     ['array', [1, 2]], ['string', 'abc'], ['nil', nil]].each do |label, value|
      begin
        say "plain chain serialize(#{label})", plain.serialize(value)
      rescue StandardError => e
        say "plain chain serialize(#{label}) RAISED", "#{e.class}: #{e.message}"
      end

      begin
        say "real chain cast(#{label})", chain.cast(value)
      rescue StandardError => e
        say "real chain cast(#{label}) RAISED", "#{e.class}: #{e.message}"
      end
    end
  end
end

RSpec.describe 'PROBE admin writes', type: :request do
  include_context 'API v3 Admin'

  let(:headers) { bearer_headers }
  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1) }

  it 'writes a month amount that is not a number' do
    patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting",
          headers: headers,
          params: { preferences: { saving_month_amount: 'abc' } }

    say 'write status', response.status
    say 'written', Spree::MembershipTierSetting.find(tier.id).preferences

    begin
      get '/api/v3/store/membership_savings', headers: headers, params: { tier_id: tier.prefixed_id }
      say 'store read status', response.status
      say 'store read body', response.parsed_body
    rescue StandardError => e
      say 'store read RAISED', "#{e.class}: #{e.message}"
    end
  end

  it 'writes a hash into a string slot' do
    patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting",
          headers: headers,
          params: { preferences: { saving_order_title: { 'nested' => 'yes' } } }

    say 'write status', response.status
    say 'written', Spree::MembershipTierSetting.find(tier.id).preferences

    get '/api/v3/store/membership_savings', headers: headers, params: { tier_id: tier.prefixed_id }
    say 'store read status', response.status
    say 'store read first row', response.parsed_body['rows']&.first
  end

  it 'writes an undeclared key' do
    patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting",
          headers: headers,
          params: { preferences: { not_declared: 'x' } }

    say 'write status', response.status
    say 'written', Spree::MembershipTierSetting.find(tier.id).preferences
    say 'serialized', Spree::MembershipTierSetting.find(tier.id).serialized_preferences
  end

  it 'writes an array preference through the rights endpoint' do
    right = create(:give_gift_right, customer_group: group,
                                     preferences: { gift_mode: 'logistics', yearly_limit: 1 })

    patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/membership_rights/#{right.prefixed_id}",
          headers: headers,
          params: { preferences: { gift_promotion_ids: %w[promo_a promo_b], yearly_limit: 2 } }

    say 'array write status', response.status
    say 'array write body', response.parsed_body['preferences']
    say 'array stored', right.reload.preferences
  end
end

RSpec.describe 'PROBE store read', type: :request do
  include_context 'API v3 Store authenticated'

  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1) }

  it 'answers the id it carries' do
    get '/api/v3/store/membership_savings', headers: headers, params: { tier_id: tier.prefixed_id }
    say 'body', response.parsed_body
    say 'tier prefixed id', tier.prefixed_id
  end

  it 'answers blanks written as empty strings, and nil written as nil' do
    tier.update!(preferences: { saving_order_title: '', saving_coupon_title: nil,
                                saving_rules: '', saving_month_amount: 0 })
    get '/api/v3/store/membership_savings', headers: headers, params: { tier_id: tier.prefixed_id }
    say 'body', response.parsed_body
  end
end
