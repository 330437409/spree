FactoryBot.define do
  factory :administrative_division, class: 'Spree::AdministrativeDivision' do
    sequence(:code) { |n| format('99%04d', n) }
    name { '测试省' }
    first_pinyin { 'C' }
    pinyin { 'ceshisheng' }
    level { 'province' }
    depth { 1 }
    dataset_version { 'nbs-2026-09-01' }
    source { 'nbs-2026' }
  end
end
