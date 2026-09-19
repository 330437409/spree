require 'spec_helper'

RSpec.describe Spree::ReverseGeocode::TencentMapper do
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

  def result(attributes)
    Spree::ReverseGeocode::Result.new({ provider: 'tencent' }.merge(attributes))
  end

  it 'reads the levels above the code the vendor answered off the tree' do
    codes = described_class.new.call(result(
                                       district_code: '110101',
                                       province_name: '北京市', city_name: '北京市', district_name: '东城区'
                                     ))

    expect(codes).to eq(province: '110000', city: '110100', district: '110101')
  end

  it 'matches the township by name inside that district' do
    codes = described_class.new.call(result(district_code: '110101', town_name: '东华门街道'))

    expect(codes[:township]).to eq('110101001')
  end

  it 'costs only the township when the vendor names it differently' do
    codes = described_class.new.call(result(district_code: '110101', town_name: '东华门'))

    expect(codes).to eq(province: '110000', city: '110100', district: '110101')
  end

  context 'when the vendor answered names and no code' do
    it 'resolves the chain by name' do
      codes = described_class.new.call(result(
                                         province_name: '北京市', city_name: '市辖区', district_name: '东城区'
                                       ))

      expect(codes).to eq(province: '110000', city: '110100', district: '110101')
    end
  end

  context 'when the code is one the tree is behind on' do
    it 'falls back to the names it was given' do
      codes = described_class.new.call(result(district_code: '999999', district_name: '东城区'))

      expect(codes).to eq(province: '110000', city: '110100', district: '110101')
    end
  end

  context 'when the point is in no division the tree carries' do
    it 'maps nothing' do
      expect(described_class.new.call(result(district_code: '999999', district_name: '不存在区'))).to eq({})
    end
  end
end
