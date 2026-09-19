require 'spec_helper'

RSpec.describe 'GET /api/v3/admin/administrative_divisions', type: :request do
  include_context 'API v3 Admin'

  let(:headers) { api_key_headers }
  let(:release) { 'nbs-2026-09-01' }

  let!(:nation) do
    create(:administrative_division, code: 'CN', name: '全国', level: 'country', depth: 0,
                                     first_pinyin: 'Q', dataset_version: release)
  end
  let!(:beijing) do
    create(:administrative_division, code: '110000', name: '北京市', level: 'province', depth: 1,
                                     parent: nation, first_pinyin: 'B', dataset_version: release)
  end
  let!(:dongcheng) do
    create(:administrative_division, code: '110101', name: '东城区', level: 'district', depth: 3,
                                     parent: beijing, first_pinyin: 'D', pinyin: 'dongchengqu',
                                     dataset_version: release)
  end

  def codes
    response.parsed_body['data'].map { |division| division['code'] }
  end

  it 'answers the collection a picker opens with' do
    get '/api/v3/admin/administrative_divisions', headers: headers

    expect(response).to have_http_status(:ok)
    expect(codes).to eq(%w[110000])
  end

  it 'cascades by the parent a picker just opened' do
    get '/api/v3/admin/administrative_divisions', params: { parent_code: '110000' }, headers: headers

    expect(codes).to eq(%w[110101])
  end

  it 'searches by name and by romanisation' do
    get '/api/v3/admin/administrative_divisions', params: { keywords: 'dongcheng' }, headers: headers

    expect(codes).to eq(%w[110101])
  end

  it 'answers the same shape the storefront reads, because it is the same read' do
    get '/api/v3/admin/administrative_divisions', headers: headers

    expect(response.parsed_body['data'].first).to include(
      'code' => '110000', 'name' => '北京市', 'level' => 'province', 'first_pinyin' => 'B', 'has_children' => true
    )
  end

  it 'refuses a request with no key' do
    get '/api/v3/admin/administrative_divisions'

    expect(response).to have_http_status(:unauthorized)
  end
end
