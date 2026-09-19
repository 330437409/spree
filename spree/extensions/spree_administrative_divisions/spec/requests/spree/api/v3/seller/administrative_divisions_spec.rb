require 'spec_helper'

RSpec.describe 'GET /api/v3/seller/administrative_divisions', type: :request do
  include_context 'API v3 Seller authenticated'

  # A seller binds their own warehouse's service area, so they read the same
  # tree the operator does — with the permission that lets them touch stock.
  let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_stock]) }
  let(:headers) { seller_headers }
  let(:release) { 'nbs-2026-09-01' }

  let!(:nation) do
    create(:administrative_division, code: 'CN', name: '全国', level: 'country', depth: 0,
                                     first_pinyin: 'Q', dataset_version: release)
  end
  let!(:beijing) do
    create(:administrative_division, code: '110000', name: '北京市', level: 'province', depth: 1,
                                     parent: nation, first_pinyin: 'B', dataset_version: release)
  end

  it 'answers the province list the picker opens with' do
    get '/api/v3/seller/administrative_divisions', headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].map { |division| division['code'] }).to eq(%w[110000])
  end

  it 'refuses a request with no session' do
    get '/api/v3/seller/administrative_divisions'

    expect(response).to have_http_status(:unauthorized)
  end
end
