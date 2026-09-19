require 'spec_helper'

RSpec.describe Spree::CoordinateNormalizer do
  describe '.normalize' do
    it 'leaves a pair that is already in the canonical system alone' do
      expect(described_class.normalize(latitude: 39.9075, longitude: 116.39723, source: 'gcj02')).
        to eq([39.9075, 116.39723])
    end

    # The offsets below are the published algorithm's own output for this pair.
    # They are pinned rather than compared against a second implementation,
    # because a normalizer that silently stops offsetting puts every shop a few
    # hundred metres from where it is — which nothing else in the suite notices.
    it 'offsets a WGS-84 pair into GCJ-02' do
      latitude, longitude = described_class.normalize(latitude: 39.9075, longitude: 116.39723, source: 'wgs84')

      expect(latitude).to be_within(0.0001).of(39.9089)
      expect(longitude).to be_within(0.0001).of(116.40347)
    end

    it 'leaves a pair outside China alone' do
      expect(described_class.normalize(latitude: 35.68, longitude: 139.76, source: 'wgs84')).to eq([35.68, 139.76])
      expect(described_class.normalize(latitude: 37.7749, longitude: -122.4194, source: 'wgs84')).
        to eq([37.7749, -122.4194])
    end

    it 'accepts the source as a symbol' do
      expect(described_class.normalize(latitude: 39.9075, longitude: 116.39723, source: :gcj02)).
        to eq([39.9075, 116.39723])
    end

    it 'refuses a system it does not know rather than guessing one' do
      expect { described_class.normalize(latitude: 39.9075, longitude: 116.39723, source: 'bd09') }.
        to raise_error(ArgumentError, /unknown coordinate system/)
    end
  end

  describe '.source_for_lookup' do
    it 'knows which lookup services already answer in GCJ-02' do
      expect(described_class.source_for_lookup(:tencent)).to eq('gcj02')
      expect(described_class.source_for_lookup(:amap)).to eq('gcj02')
      expect(described_class.source_for_lookup(:nominatim)).to eq('wgs84')
      expect(described_class.source_for_lookup('google')).to eq('wgs84')
    end
  end
end
