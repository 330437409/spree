require 'spec_helper'

RSpec.describe 'POST /api/v3/store/coupon_campaigns/:coupon_campaign_id/draws', type: :request do
  include_context 'API v3 Store authenticated'

  let(:campaign) { create(:coupon_campaign, store: store) }

  def draw(campaign_id: campaign.prefixed_id, headers_override: headers)
    post "/api/v3/store/coupon_campaigns/#{campaign_id}/draws", headers: headers_override
  end

  it 'answers the coupon the draw won' do
    draw

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['status']).to eq('unused')
    expect(response.parsed_body['source']).to eq('draw')
    expect(response.parsed_body['campaign_id']).to eq(campaign.prefixed_id)
    expect(response.parsed_body['promotion']).to include('name' => campaign.promotion.name)
    expect(Spree::CouponHolding.for_customer(user).count).to eq(1)
  end

  it 'gives the coupon the campaign’s own life' do
    campaign.update!(preferred_valid_for_days: 7)

    draw

    expect(response.parsed_body['expires_at']).to be_present
    expect(Time.iso8601(response.parsed_body['expires_at'])).to be_within(1.minute).of(7.days.from_now)
  end

  it 'refuses a campaign that is not giving coupons out, and says why' do
    campaign.update!(status: 'paused')

    draw

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/not giving coupons out/i)
  end

  it 'refuses once the customer has taken what the campaign allows, and says why' do
    draw
    draw

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/already taken this coupon/i)
    expect(Spree::CouponHolding.count).to eq(1)
  end

  it 'refuses a customer the campaign does not admit' do
    settled = create(:new_customer_coupon_campaign, store: store)
    user.update!(created_at: 90.days.ago)

    draw(campaign_id: settled.prefixed_id)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/not eligible/i)
  end

  it 'answers 404 for a campaign of another store' do
    draw(campaign_id: create(:coupon_campaign, store: create(:store)).prefixed_id)

    expect(response).to have_http_status(:not_found)
  end

  it 'requires a signed-in customer' do
    draw(headers_override: api_key_headers)

    expect(response).to have_http_status(:unauthorized)
  end
end
