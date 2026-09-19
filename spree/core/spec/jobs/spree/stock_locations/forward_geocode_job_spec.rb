require 'spec_helper'

RSpec.describe Spree::StockLocations::ForwardGeocodeJob do
  subject(:geocode) { described_class.new.perform(stock_location.id) }

  let(:stock_location) do
    create(:stock_location, address1: '东华门大街 1 号', city: '北京市', zipcode: '100006', state_name: '北京市')
  end

  # Tiananmen, as an address lookup answers it: WGS-84.
  let(:coordinates) { [39.9075, 116.39723] }
  let(:lookup) { :nominatim }

  before do
    allow(Geocoder).to receive(:config).and_return(double(lookup: lookup))
    allow(Geocoder).to receive(:coordinates).
      with(stock_location.address.geocoder_address, country: stock_location.address.country_iso3).
      and_return(coordinates)
  end

  it 'writes the pair the lookup answered, in the canonical system' do
    geocode

    stock_location.reload
    expect(stock_location.latitude).to be_within(0.0001).of(39.9089)
    expect(stock_location.longitude).to be_within(0.0001).of(116.40347)
    expect(stock_location.geocoded_at).to be_present
    expect(stock_location.geocode_status).to eq('success')
  end

  it 'records which provider answered' do
    geocode

    expect(stock_location.reload.geocode_provider).to eq('nominatim')
  end

  context 'when the lookup already answers in GCJ-02' do
    let(:lookup) { :tencent }
    let(:coordinates) { [39.9089, 116.40347] }

    it 'stores the pair as it is' do
      geocode

      expect(stock_location.reload.latitude).to be_within(0.000001).of(39.9089)
      expect(stock_location.reload.longitude).to be_within(0.000001).of(116.40347)
    end
  end

  # The lookup is somebody else's network, and this job runs on every address
  # change: a suite that drains jobs must not turn into a suite that makes
  # requests, and a warehouse must not take the queue down with it.
  context 'when the lookup itself fails' do
    before do
      allow(Geocoder).to receive(:coordinates).
        and_raise(StandardError.new('Real HTTP connections are disabled'))
    end

    it 'records the failure rather than raising' do
      expect { geocode }.not_to raise_error

      expect(stock_location.reload.geocode_status).to eq('failed')
    end

    it 'reports the error it caught, so a broken lookup is visible' do
      allow(Rails.error).to receive(:report)

      geocode

      expect(Rails.error).to have_received(:report).with(
        an_instance_of(StandardError),
        handled: true,
        context: { stock_location_id: stock_location.id },
        source: 'spree.core'
      )
    end
  end

  context 'when the location has no address to geocode' do
    let(:stock_location) { create(:stock_location, address1: nil, city: nil) }

    it 'asks the lookup nothing and leaves the location alone' do
      expect(Geocoder).not_to receive(:coordinates)

      geocode

      stock_location.reload
      expect(stock_location.geocode_status).to be_nil
      expect(stock_location.geocoded_at).to be_nil
    end
  end

  context 'when the address cannot be geocoded' do
    let(:coordinates) { nil }

    it 'marks the location failed, leaves the coordinates alone and reports it' do
      expect(Rails.error).to receive(:report).with(
        an_instance_of(described_class::GeocodeError),
        handled: false,
        context: { stock_location_id: stock_location.id },
        source: 'spree.core'
      )

      geocode

      stock_location.reload
      expect(stock_location.geocode_status).to eq('failed')
      expect(stock_location.latitude).to be_nil
      expect(stock_location.geocode_provider).to eq('nominatim')
    end
  end
end
