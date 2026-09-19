require 'spec_helper'

RSpec.describe 'GET /api/v3/store/administrative_divisions', type: :request do
  include_context 'API v3 Store'

  let(:headers) { api_key_headers }
  let(:release) { 'nbs-2023-06-30' }

  before do
    nation = create(:administrative_division, code: 'CN', name: '全国', level: 'country', depth: 0,
                                              first_pinyin: 'Q', pinyin: 'quanguo', dataset_version: release)
    beijing = create(:administrative_division, code: '110000', name: '北京市', level: 'province', depth: 1,
                                               parent: nation, first_pinyin: 'B', pinyin: 'beijingshi',
                                               dataset_version: release)
    create(:administrative_division, code: '120000', name: '天津市', level: 'province', depth: 1,
                                     parent: nation, first_pinyin: 'T', pinyin: 'tianjinshi',
                                     dataset_version: release)
    create(:administrative_division, code: '110100', name: '市辖区', level: 'city', depth: 2,
                                     parent: beijing, first_pinyin: 'S', pinyin: 'shixiaqu',
                                     dataset_version: release)
  end

  def division_codes
    response.parsed_body['data'].map { |division| division['code'] }
  end

  describe 'the default answer' do
    it 'is the province list, sorted the way the picker sorts it' do
      get '/api/v3/store/administrative_divisions', headers: headers

      expect(response).to have_http_status(:ok)
      expect(division_codes).to eq(%w[110000 120000])
      expect(response.parsed_body['data'].first).to include(
        'code' => '110000', 'name' => '北京市', 'level' => 'province', 'first_pinyin' => 'B'
      )
    end

    it 'says which nodes are worth asking again for' do
      get '/api/v3/store/administrative_divisions', headers: headers

      by_code = response.parsed_body['data'].index_by { |division| division['code'] }
      expect(by_code['110000']['has_children']).to be true
      expect(by_code['120000']['has_children']).to be false
    end
  end

  describe 'the lazy cascade' do
    it 'answers the children of the node the picker just opened' do
      get '/api/v3/store/administrative_divisions', params: { parent_code: '110000' }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(division_codes).to eq(%w[110100])
    end

    it 'answers nothing for a code this release does not carry' do
      get '/api/v3/store/administrative_divisions', params: { parent_code: '999999' }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']).to be_empty
    end
  end

  describe 'the search box' do
    it 'finds a node by name' do
      get '/api/v3/store/administrative_divisions', params: { keywords: '北京' }, headers: headers

      expect(division_codes).to eq(%w[110000])
    end

    it 'finds it by its romanisation too' do
      get '/api/v3/store/administrative_divisions', params: { keywords: 'tianjin' }, headers: headers

      expect(division_codes).to eq(%w[120000])
    end
  end

  describe 'levels' do
    it 'answers one level when asked for one' do
      get '/api/v3/store/administrative_divisions', params: { level: 'city' }, headers: headers

      expect(division_codes).to eq(%w[110100])
    end
  end

  describe 'authentication' do
    it 'refuses a request with no publishable key' do
      get '/api/v3/store/administrative_divisions'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'caching' do
    around do |example|
      store = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = store
    end

    it 'answers the same filter from the cache rather than the table' do
      get '/api/v3/store/administrative_divisions', headers: headers
      expect(division_codes).to eq(%w[110000 120000])

      Spree::AdministrativeDivision.delete_all

      get '/api/v3/store/administrative_divisions', headers: headers

      expect(division_codes).to eq(%w[110000 120000])
    end

    it 'reads the table again when a new release arrives' do
      get '/api/v3/store/administrative_divisions', headers: headers

      Spree::AdministrativeDivision.delete_all
      create(:administrative_division, code: '310000', name: '上海市', level: 'province', depth: 1,
                                       first_pinyin: 'S', pinyin: 'shanghaishi',
                                       dataset_version: 'nbs-2026-01-01')
      Rails.cache.delete(Spree::AdministrativeDivision.current_dataset_version_key)

      get '/api/v3/store/administrative_divisions', headers: headers

      expect(division_codes).to eq(%w[310000])
    end
  end
end
