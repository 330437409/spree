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

  factory :reverse_geocode_cache, class: 'Spree::ReverseGeocodeCache' do
    geohash { 'wx4g0b' }
    provider { 'tencent' }
    coordinate_system { 'gcj02' }
    dataset_version { 'nbs-2026-09-01' }
    resolved { true }
    province_code { '110000' }
    city_code { '110100' }
    district_code { '110101' }
    expires_at { 30.days.from_now }
  end
end
