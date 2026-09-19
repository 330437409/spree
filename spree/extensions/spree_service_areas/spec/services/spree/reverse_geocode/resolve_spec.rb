require 'spec_helper'

RSpec.describe Spree::ReverseGeocode::Resolve do
  # A method rather than a `subject`: asking twice is the behaviour under test
  # in half of these examples, and a memoised subject would answer the same
  # object twice and prove nothing.
  def resolve(source: 'gcj02', latitude: self.latitude, longitude: self.longitude)
    described_class.call(latitude: latitude, longitude: longitude, source: source, store: store, providers: providers)
  end

  let(:store) { create(:store) }
  let(:latitude) { 39.9089 }
  let(:longitude) { 116.40347 }

  let(:tencent) { instance_double(Spree::ReverseGeocode::Tencent) }
  let(:amap) { instance_double(Spree::ReverseGeocode::Tencent, provider_name: 'amap') }
  let(:providers) { { 'tencent' => tencent } }

  let(:answer) do
    Spree::ReverseGeocode::Result.new(
      provider: 'tencent', latitude: latitude, longitude: longitude,
      district_code: '110101', province_name: '北京市', city_name: '北京市',
      district_name: '东城区', town_name: '东华门街道'
    )
  end

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

  before do
    allow(tencent).to receive(:reverse_geocode).and_return(answer)
  end

  it 'answers the administrative path the provider described' do
    expect(resolve.path).to eq(country: 'CN', province: '110000', city: '110100',
                               district: '110101', township: '110101001')
  end

  it 'attributes the answer to the vendor that produced it' do
    resolution = resolve

    expect(resolution.provider).to eq('tencent')
    expect(resolution).not_to be_cached
  end

  it 'answers the second request for the same cell from the cache' do
    resolve

    expect(tencent).to have_received(:reverse_geocode).once

    cached = resolve
    expect(tencent).to have_received(:reverse_geocode).once
    expect(cached).to be_cached
    expect(cached).not_to be_stale
    expect(cached.path).to eq(resolve.path)
  end

  describe 'a point the provider finds no division for' do
    let(:answer) { Spree::ReverseGeocode::Result.new(provider: 'tencent', latitude: latitude, longitude: longitude) }

    it 'is an answer, cached like any other' do
      expect(resolve.path).to eq({})
      expect(tencent).to have_received(:reverse_geocode).once

      cached = resolve
      expect(cached).to be_cached
      expect(cached.path).to eq({})
    end
  end

  describe 'a provider that refuses' do
    before do
      allow(tencent).to receive(:reverse_geocode).
        and_raise(Spree::ReverseGeocode::ApiError.new('Tencent LBS refused the reverse geocoding request: 此key已过期'))
    end

    context 'with a fallback configured' do
      before do
        # A vendor is registered, not hard-coded: this one is a second name for
        # the same adapter, which is all the fallback path needs to be exercised.
        Spree::ReverseGeocode::Provider.register('amap', provider: 'Spree::ReverseGeocode::Tencent',
                                                         mapper: 'Spree::ReverseGeocode::TencentMapper')
        store.update!(preferred_reverse_geocode_fallback_provider: 'amap')
        allow(amap).to receive(:reverse_geocode).and_return(answer)
      end

      let(:providers) { { 'tencent' => tencent, 'amap' => amap } }

      it 'asks the fallback and attributes the answer to it' do
        expect(resolve.provider).to eq('amap')
        expect(amap).to have_received(:reverse_geocode).once
      end

      it 'caches the fallback’s answer under the fallback, so the next lookup asks it first' do
        resolve

        expect(Spree::ReverseGeocodeCache.pluck(:provider)).to eq(['amap'])

        described_class.call(latitude: latitude, longitude: longitude, source: 'gcj02', store: store, providers: providers)
        expect(amap).to have_received(:reverse_geocode).once
      end
    end

    context 'with nothing cached' do
      it 'refuses with the provider’s own words' do
        expect { resolve }.to raise_error(Spree::ReverseGeocode::ApiError, /此key已过期/)
      end
    end

    context 'with an expired entry cached' do
      before do
        create(:reverse_geocode_cache, geohash: Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude),
                                       provider: 'tencent', dataset_version: release,
                                       expires_at: 1.day.ago)
      end

      it 'serves the stale answer rather than failing the request' do
        resolution = resolve

        expect(resolution).to be_stale
        expect(resolution).to be_cached
        expect(resolution.path[:district]).to eq('110101')
      end
    end
  end

  describe 'the cache it writes' do
    before { resolve }

    it 'is keyed by the cell, the vendor, the system and the tree release' do
      entry = Spree::ReverseGeocodeCache.last

      expect(entry.geohash).to eq(Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude))
      expect(entry.provider).to eq('tencent')
      expect(entry.coordinate_system).to eq('gcj02')
      expect(entry.dataset_version).to eq(release)
      expect(entry).to be_resolved
    end

    it 'expires after the store’s time to live' do
      expect(Spree::ReverseGeocodeCache.last.expires_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe 'a pair that arrives in another system' do
    let(:latitude) { 39.9075 }
    let(:longitude) { 116.39723 }

    it 'asks the provider in the canonical one' do
      resolve(source: 'wgs84')

      expect(tencent).to have_received(:reverse_geocode).with(latitude: 39.9089033864039, longitude: 116.40347336470487)
    end
  end
end
