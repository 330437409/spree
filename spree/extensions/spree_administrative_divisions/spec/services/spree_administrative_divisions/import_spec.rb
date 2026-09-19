require 'spec_helper'
require 'tmpdir'

RSpec.describe SpreeAdministrativeDivisions::Import do
  around do |example|
    Dir.mktmpdir do |dir|
      @data_root = dir
      example.run
    end
  end

  # A release is two files: everything above the township level, and the
  # townships. The specs build their own rather than reading the shipped
  # release, so a case can say exactly what it is importing.
  def write_release(version, divisions:, townships: [], source: 'test-source', source_updated_at: '2026-01-01')
    release = File.join(@data_root, version)
    FileUtils.mkdir_p(release)

    payload = { 'dataset_version' => version, 'source' => source, 'source_updated_at' => source_updated_at }
    File.write(File.join(release, 'divisions.json'), JSON.generate(payload.merge('divisions' => divisions)))
    File.write(File.join(release, 'townships.json'), JSON.generate(payload.merge('divisions' => townships))) if townships.any?
    release
  end

  def node(code, name, level, depth, parent_code)
    {
      'code' => code, 'name' => name, 'level' => level, 'depth' => depth,
      'parent_code' => parent_code, 'first_pinyin' => name[0].upcase, 'pinyin' => name.downcase
    }
  end

  # 全国 → 北京市 → 市辖区 → 东城区 → 东华门街道, and a second province so a
  # release can drop a branch without emptying the table.
  def three_levels
    [
      node('CN', '全国', 'country', 0, nil),
      node('110000', '北京市', 'province', 1, 'CN'),
      node('110100', '市辖区', 'city', 2, '110000'),
      node('110101', '东城区', 'district', 3, '110100'),
      node('120000', '天津市', 'province', 1, 'CN')
    ]
  end

  def townships
    [node('110101001', '东华门街道', 'township', 4, '110101')]
  end

  let(:import) do
    ->(version, **options) { described_class.call(dataset_version: version, data_root: @data_root, **options) }
  end

  describe 'a fresh release' do
    before { write_release('test-2026-01-01', divisions: three_levels, townships: townships) }

    it 'imports every level and reports what it wrote' do
      result = import.call('test-2026-01-01')

      expect(result).to be_success
      expect(result.value[:counts]).to eq('country' => 1, 'province' => 2, 'city' => 1, 'district' => 1, 'township' => 1)
      expect(Spree::AdministrativeDivision.count).to eq(6)
    end

    it 'links each node to its parent and stamps its level and depth' do
      import.call('test-2026-01-01')

      district = Spree::AdministrativeDivision.find_by(code: '110101')
      expect(district.parent.code).to eq('110100')
      expect(district.parent.parent.code).to eq('110000')
      expect(district.level).to eq('district')
      expect(district.depth).to eq(3)
      expect(district.parent.parent.parent.code).to eq('CN')
    end

    it 'carries the release it came from onto every row' do
      import.call('test-2026-01-01')

      row = Spree::AdministrativeDivision.find_by(code: '110000')
      expect(row.dataset_version).to eq('test-2026-01-01')
      expect(row.source).to eq('test-source')
      expect(row.source_updated_at).to eq(Date.new(2026, 1, 1))
    end

    it 'imports nothing twice when it runs again' do
      import.call('test-2026-01-01')
      result = import.call('test-2026-01-01')

      expect(result).to be_success
      expect(Spree::AdministrativeDivision.count).to eq(6)
      expect(result.value[:removed]).to eq(0)
    end
  end

  describe 'a newer release' do
    before do
      write_release('test-2026-01-01', divisions: three_levels)
      write_release('test-2026-02-01', divisions: three_levels.first(4), source: 'test-source', source_updated_at: '2026-02-01')
      import.call('test-2026-01-01')
    end

    it 'replaces the rows the previous release left behind' do
      result = import.call('test-2026-02-01')

      expect(result).to be_success
      expect(result.value[:removed]).to eq(1)
      expect(Spree::AdministrativeDivision.pluck(:code)).not_to include('120000')
      expect(Spree::AdministrativeDivision.count).to eq(4)
      expect(Spree::AdministrativeDivision.distinct.pluck(:dataset_version)).to eq(['test-2026-02-01'])
    end
  end

  describe 'choosing levels' do
    before { write_release('test-2026-01-01', divisions: three_levels, townships: townships) }

    it 'imports only the levels it was asked for' do
      result = import.call('test-2026-01-01', levels: %w[country province city district])

      expect(result).to be_success
      expect(result.value[:counts]).not_to have_key('township')
      expect(Spree::AdministrativeDivision.at_level('township')).to be_empty
      expect(Spree::AdministrativeDivision.count).to eq(5)
    end

    it 'removes levels a previous, wider import had left' do
      import.call('test-2026-01-01')
      result = import.call('test-2026-01-01', levels: %w[country province city district])

      expect(result.value[:removed]).to eq(1)
      expect(Spree::AdministrativeDivision.at_level('township')).to be_empty
    end
  end

  describe 'refusals' do
    it 'fails when the release directory does not exist' do
      expect(import.call('test-2020-01-01')).to be_failure
    end

    it 'refuses a release that carries one code twice' do
      write_release('test-2026-01-01', divisions: three_levels + [node('110101', '东城区', 'district', 3, '110100')])

      expect { import.call('test-2026-01-01') }.to raise_error(ArgumentError, /duplicate codes: 110101/)
    end

    it 'refuses a release whose file names a different version than the directory' do
      write_release('test-2026-01-01', divisions: three_levels)
      File.write(File.join(@data_root, 'test-2026-01-01', 'divisions.json'),
                 File.read(File.join(@data_root, 'test-2026-01-01', 'divisions.json')).sub('test-2026-01-01', 'test-2026-09-09'))

      expect { import.call('test-2026-01-01') }.to raise_error(ArgumentError, /the directory names the release/)
    end
  end
end
