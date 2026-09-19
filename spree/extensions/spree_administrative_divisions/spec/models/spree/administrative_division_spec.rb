require 'spec_helper'

RSpec.describe Spree::AdministrativeDivision, type: :model do
  describe 'validations' do
    it 'is valid with the attributes the import supplies' do
      expect(build(:administrative_division)).to be_valid
    end

    it 'requires the fields the dataset always carries' do
      division = build(:administrative_division, name: nil, first_pinyin: nil,
                                                 dataset_version: nil, source: nil, code: nil, depth: nil)

      expect(division).not_to be_valid
      expect(division.errors.attribute_names).to include(:code, :name, :first_pinyin, :dataset_version, :source, :depth)
    end

    it 'refuses a level outside the five the tree has' do
      expect(build(:administrative_division, level: 'borough')).not_to be_valid
    end

    it 'refuses a negative depth' do
      expect(build(:administrative_division, depth: -1)).not_to be_valid
    end

    it 'refuses a code another division already has' do
      create(:administrative_division, code: '110000')

      expect(build(:administrative_division, code: '110000')).not_to be_valid
    end
  end

  describe 'the tree' do
    it 'answers its parent and its children' do
      province = create(:administrative_division, code: '110000', level: 'province', depth: 1)
      city = create(:administrative_division, code: '110100', level: 'city', depth: 2, parent: province)

      expect(city.parent).to eq(province)
      expect(province.children).to eq([city])
    end

    it 'takes its children with it when a node is destroyed' do
      province = create(:administrative_division, code: '110000')
      create(:administrative_division, code: '110100', parent: province)

      expect { province.destroy }.to change(Spree::AdministrativeDivision, :count).by(-2)
    end
  end

  describe '.at_level' do
    it 'answers one level of the tree' do
      province = create(:administrative_division, code: '110000', level: 'province')
      create(:administrative_division, code: '110100', level: 'city')

      expect(described_class.at_level('province')).to eq([province])
    end
  end

  describe 'addressing' do
    it 'exposes a prefixed id rather than the row id' do
      division = create(:administrative_division)

      expect(division.prefixed_id).to start_with('adm_')
    end
  end

  describe '#subtree_code_prefix' do
    # The digits are the level's: a province is two, a city four, a district
    # six. Everything under a node shares them, which is what makes a subtree
    # read one indexed `LIKE` rather than a walk.
    {
      'country' => 'CN',
      'province' => '110000',
      'city' => '110100',
      'district' => '110110',
      'township' => '110110001'
    }.each do |level, code|
      it "answers the shared digits for a #{level}" do
        division = create(:administrative_division, code: code, level: level)

        expect(division.subtree_code_prefix).to eq(code[0, described_class::PREFIX_LENGTHS[level]])
      end
    end

    it 'answers nothing at the root, where every code is below' do
      nation = create(:administrative_division, code: 'CN', level: 'country')

      expect(nation.subtree_code_prefix).to eq('')
    end

    it 'keeps a district that ends in a zero whole, so it does not match its siblings' do
      district = create(:administrative_division, code: '110110', level: 'district')

      expect(district.subtree_code_prefix).to eq('110110')
    end
  end
end
