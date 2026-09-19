require 'spec_helper'

RSpec.describe Spree::SellerRouting::Locate do
  subject(:decision) do
    described_class.call(latitude: latitude, longitude: longitude, source: 'gcj02', store: store)
  end

  let(:store) { create(:store) }
  # 天安门, the point every example places.
  let(:latitude) { 39.9089 }
  let(:longitude) { 116.40347 }
  let(:release) { 'nbs-2023-06-30' }

  let!(:nation) do
    create(:administrative_division, code: 'CN', name: '全国', level: 'country', depth: 0, dataset_version: release)
  end
  let!(:beijing) do
    create(:administrative_division, code: '110000', name: '北京市', level: 'province', depth: 1,
                                     parent: nation, dataset_version: release)
  end
  let!(:shixiaqu) do
    create(:administrative_division, code: '110100', name: '市辖区', level: 'city', depth: 2,
                                     parent: beijing, dataset_version: release)
  end
  let!(:dongcheng) do
    create(:administrative_division, code: '110101', name: '东城区', level: 'district', depth: 3,
                                     parent: shixiaqu, dataset_version: release)
  end
  let!(:donghuamen) do
    create(:administrative_division, code: '110101001', name: '东华门街道', level: 'township', depth: 4,
                                     parent: dongcheng, dataset_version: release)
  end

  let(:seller) { create(:seller, :approved) }

  def warehouse(division:, seller: self.seller, **attributes)
    create(:stock_location, seller: seller, administrative_division: division, store: store, **attributes)
  end

  # The point is answered from the cache, so no example here talks to a vendor:
  # the geocoding has its own specs, and this one is about the matching.
  before do
    create(:reverse_geocode_cache,
           geohash: Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude),
           provider: store.preferred_reverse_geocode_provider,
           dataset_version: release,
           district_code: '110101')
  end

  it 'answers the seller whose warehouse is bound to the resolved division' do
    binding = warehouse(division: dongcheng)

    expect(decision).to be_matched
    expect(decision.seller).to eq(seller)
    expect(decision.stock_location).to eq(binding)
    expect(decision.division).to eq(dongcheng)
    expect(decision.match_type).to eq('district')
    expect(decision.polygon_result).to eq('not_required')
    expect(decision.depth).to eq(3)
  end

  it 'prefers the deeper of two bindings that both cover the point' do
    warehouse(division: beijing)
    deepest = warehouse(division: dongcheng)

    expect(decision.stock_location).to eq(deepest)
  end

  it 'lets a township binding beat the district above it' do
    warehouse(division: dongcheng)
    township_binding = warehouse(division: donghuamen)
    # The township the point resolved to, not just the district.
    Spree::ReverseGeocodeCache.update_all(township_code: '110101001')

    expect(decision.stock_location).to eq(township_binding)
    expect(decision.match_type).to eq('township')
  end

  it 'answers the national seller whose warehouse is bound to the root' do
    national = warehouse(division: nation)

    expect(decision.stock_location).to eq(national)
    expect(decision.match_type).to eq('country')
  end

  describe 'a polygon' do
    let(:around_the_point) do
      [[[116.30, 39.85], [116.50, 39.85], [116.50, 39.95], [116.30, 39.95], [116.30, 39.85]]]
    end
    let(:around_shanghai) do
      [[[121.40, 31.15], [121.60, 31.15], [121.60, 31.25], [121.40, 31.25], [121.40, 31.15]]]
    end

    it 'narrows a binding that the point falls inside' do
      warehouse(division: dongcheng, polygon: around_the_point)

      expect(decision).to be_matched
      expect(decision.polygon_result).to eq('matched')
    end

    it 'skips a warehouse whose polygon excludes the point, and takes the next candidate' do
      warehouse(division: dongcheng, polygon: around_shanghai)
      fallback = warehouse(division: beijing)

      expect(decision.stock_location).to eq(fallback)
      expect(decision.match_type).to eq('province')
    end
  end

  describe 'who can serve' do
    it 'ignores a warehouse that is not active' do
      warehouse(division: dongcheng, active: false)

      expect(decision).not_to be_matched
    end

    it 'ignores a seller who is still onboarding' do
      warehouse(division: dongcheng, seller: create(:seller, :onboarding))

      expect(decision).not_to be_matched
    end

    it 'ignores a seller who is on holiday' do
      warehouse(division: dongcheng, seller: create(:seller, :on_holiday))

      expect(decision).not_to be_matched
    end
  end

  it 'answers no match rather than failing when nothing covers the point' do
    warehouse(division: donghuamen)

    expect(decision).not_to be_matched
    expect(decision.seller).to be_nil
    expect(decision.division).to be_nil
    expect(decision.match_type).to be_nil
  end

  it 'answers no match for a point that resolves to no division at all' do
    Spree::ReverseGeocodeCache.update_all(resolved: false, province_code: nil, city_code: nil, district_code: nil)

    expect(decision).not_to be_matched
  end

  describe 'the distance it reports' do
    it 'measures from the buyer to the warehouse, in kilometres' do
      warehouse(division: dongcheng, latitude: 39.95, longitude: 116.45)

      # About six kilometres north-east of the point every example uses; in
      # miles it would read 3.8, which is what this is here to catch.
      expect(decision.distance_km).to be_within(0.2).of(6.05)
    end

    it 'is absent when the warehouse has no coordinates yet' do
      warehouse(division: dongcheng, latitude: nil, longitude: nil)

      expect(decision.distance_km).to be_nil
    end
  end

  describe 'when the providers are unreachable' do
    let(:provider) { instance_double(Spree::ReverseGeocode::Tencent) }

    before do
      Spree::ReverseGeocodeCache.update_all(expires_at: 1.day.ago)
      allow(Spree::ReverseGeocode::Tencent).to receive(:new).and_return(provider)
      allow(provider).to receive(:reverse_geocode).
        and_raise(Spree::ReverseGeocode::ApiError.new('Tencent LBS refused the reverse geocoding request: 此key已过期'))
    end

    it 'answers from the expired entry and says the answer is old' do
      binding = warehouse(division: dongcheng)

      expect(decision.stock_location).to eq(binding)
      expect(decision).to be_stale
    end
  end
end
