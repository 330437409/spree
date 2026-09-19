# The tree every routing spec places its point in: 全国 → 北京市 → 市辖区 → 东城区
# → 东华门街道, with the codes the shipped release carries, so the code arithmetic
# the reads rely on (a subtree is a prefix) is exercised rather than assumed.
RSpec.shared_context 'the division tree around 天安门' do
  let(:release) { 'nbs-2023-06-30' }

  let!(:nation) do
    create(:administrative_division, code: 'CN', name: '全国', level: 'country', depth: 0,
                                     first_pinyin: 'Q', dataset_version: release)
  end

  let!(:beijing) do
    create(:administrative_division, code: '110000', name: '北京市', level: 'province', depth: 1,
                                     parent: nation, first_pinyin: 'B', dataset_version: release)
  end

  let!(:shixiaqu) do
    create(:administrative_division, code: '110100', name: '市辖区', level: 'city', depth: 2,
                                     parent: beijing, first_pinyin: 'S', dataset_version: release)
  end

  let!(:dongcheng) do
    create(:administrative_division, code: '110101', name: '东城区', level: 'district', depth: 3,
                                     parent: shixiaqu, first_pinyin: 'D', dataset_version: release)
  end

  let!(:donghuamen) do
    create(:administrative_division, code: '110101001', name: '东华门街道', level: 'township', depth: 4,
                                     parent: dongcheng, first_pinyin: 'D', dataset_version: release)
  end

  # A province the point is not in, for the reads that must not answer with it —
  # and one district inside it, so a spec can move the point there.
  let!(:shanghai) do
    create(:administrative_division, code: '310000', name: '上海市', level: 'province', depth: 1,
                                     parent: nation, first_pinyin: 'S', dataset_version: release)
  end

  let!(:huangpu) do
    create(:administrative_division, code: '310101', name: '黄浦区', level: 'district', depth: 3,
                                     parent: shanghai, first_pinyin: 'H', dataset_version: release)
  end
end
