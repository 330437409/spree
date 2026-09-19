require 'spec_helper'

RSpec.describe Spree::ReverseGeocode::Tencent do
  subject(:result) { described_class.new(key: 'a-key', client: client).reverse_geocode(latitude: 39.9089, longitude: 116.40347) }

  let(:client) { instance_double(Spree::ReverseGeocode::Client) }

  # Recorded from the vendor's own documentation, including the shape of the
  # awkward parts: one `adcode` for three levels, the township as a reference
  # with a name rather than a code.
  let(:payload) do
    {
      'status' => 0,
      'message' => 'query ok',
      'result' => {
        'address' => '北京市东城区东华门街道东华门大街1号',
        'address_component' => {
          'nation' => '中国',
          'province' => '北京市',
          'city' => '北京市',
          'district' => '东城区',
          'street' => '东华门大街',
          'street_number' => '1号'
        },
        'ad_info' => {
          'nation' => '中国',
          'province' => '北京市',
          'city' => '北京市',
          'district' => '东城区',
          'adcode' => '110101'
        },
        'address_reference' => {
          'town' => { 'id' => '1234567890', 'title' => '东华门街道' }
        }
      }
    }
  end

  before do
    allow(client).to receive(:get).and_return(payload)
  end

  it 'asks the vendor for the pair, with the key' do
    result

    expect(client).to have_received(:get).with(
      described_class::ENDPOINT,
      location: '39.9089,116.40347',
      key: 'a-key',
      get_poi: 0
    )
  end

  it 'answers the levels as the vendor named them, and the code it knows' do
    expect(result.province_name).to eq('北京市')
    expect(result.city_name).to eq('北京市')
    expect(result.district_name).to eq('东城区')
    expect(result.town_name).to eq('东华门街道')
    expect(result.district_code).to eq('110101')
    expect(result.provider).to eq('tencent')
    expect(result).to be_located
  end

  it 'carries the pair it answered for' do
    expect(result.latitude).to eq(39.9089)
    expect(result.longitude).to eq(116.40347)
  end

  context 'when the vendor refuses' do
    let(:payload) { { 'status' => 120, 'message' => '此key每日调用量已达到上限' } }

    it 'refuses with the provider’s own words, which say what to fix' do
      expect { result }.to raise_error(Spree::ReverseGeocode::ApiError, /此key每日调用量已达到上限/)
    end

    it 'names itself as the source of the refusal' do
      expect { result }.to raise_error(Spree::ReverseGeocode::ApiError) { |error|
        expect(error.code).to eq(:reverse_geocode_refused)
      }
    end
  end

  context 'when the vendor knows the point but no division' do
    let(:payload) { { 'status' => 0, 'result' => { 'ad_info' => {}, 'address_component' => {} } } }

    it 'answers an unlocated result rather than failing' do
      expect(result).not_to be_located
      expect(result.district_code).to be_nil
    end
  end
end
