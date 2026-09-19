require 'spec_helper'

RSpec.describe Spree::StockLocation, type: :model do
  # The API reads and writes a warehouse's binding by code — a code survives a
  # re-import of the tree and a row id does not — so core's model owns the
  # translation and no client has to. It is spec'd where the tree is, because
  # that is what the translation needs and core itself never loads this gem.
  let(:stock_location) { build(:stock_location) }
  let(:province) do
    create(:administrative_division, code: '110000', name: '北京市', level: 'province', depth: 1)
  end
  let(:district) do
    create(:administrative_division, code: '110101', name: '东城区', level: 'district', depth: 3, parent: province)
  end

  describe '#administrative_division_code' do
    it 'binds the division a code names, and answers it back' do
      stock_location.administrative_division_code = district.code

      expect(stock_location.administrative_division).to eq(district)
      expect(stock_location.administrative_division_code).to eq('110101')
    end

    it 'answers the code of a binding made the other way round' do
      stock_location.administrative_division = province

      expect(stock_location.administrative_division_code).to eq('110000')
    end

    it 'refuses a code this release does not carry rather than unbinding the warehouse' do
      stock_location.administrative_division_code = '999999'

      expect(stock_location).not_to be_valid
      expect(stock_location.errors[:administrative_division_code]).to be_present
    end

    it 'unbinds when the code is blank' do
      stock_location.administrative_division_code = district.code
      stock_location.administrative_division_code = '  '

      expect(stock_location.administrative_division).to be_nil
      expect(stock_location).to be_valid
    end
  end
end
