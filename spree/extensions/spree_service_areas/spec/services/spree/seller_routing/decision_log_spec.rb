require 'spec_helper'

RSpec.describe Spree::SellerRouting::DecisionLog do
  let(:latitude) { 39.9089 }
  let(:longitude) { 116.40347 }

  let(:decision) do
    Spree::SellerRouting::Decision.new(
      match_type: 'district', polygon_result: 'matched', distance_km: 1.2,
      cached: true, provider: 'tencent', candidate_count: 3, polygon_rejections: 1,
      resolved_division_code: '110101'
    )
  end

  def publish(**options)
    described_class.publish(
      decision: decision, latitude: latitude, longitude: longitude,
      request_id: 'req_1', latency_ms: 12.5, **options
    )
  end

  def events
    @events ||= []
  end

  around do |example|
    subscription = ActiveSupport::Notifications.subscribe(described_class::NOTIFICATION) do |*args|
      events << args.last
    end
    example.run
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it 'says what the routing decided and what it decided it from' do
    publish

    expect(events.length).to eq(1)
    expect(events.first).to include(
      request_id: 'req_1',
      provider: 'tencent',
      cache_hit: true,
      stale: false,
      resolved_division: '110101',
      candidate_count: 3,
      polygon_result: 'matched',
      polygon_rejections: 1,
      match_type: 'district',
      matched: false,
      distance_km: 1.2,
      latency_ms: 12.5
    )
  end

  # The log answers "why did this customer land on this seller", and that
  # question does not need to know where they were standing.
  it 'carries the coordinate as a cell rather than as itself' do
    publish

    expect(events.first[:coordinate_hash]).to eq(
      Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude,
                                            precision: described_class::CELL_PRECISION)
    )
    expect(events.first.values).not_to include(latitude, longitude)
  end

  it 'answers a different cell for a point a district away' do
    publish
    described_class.publish(decision: decision, latitude: 31.2304, longitude: 121.4737)

    expect(events.map { |event| event[:coordinate_hash] }.uniq.length).to eq(2)
  end

  it 'reports a failure as its own event, carrying the provider’s error code' do
    described_class.publish_failure(
      error: Spree::ReverseGeocode::ApiError.new('Tencent LBS refused the reverse geocoding request: 此key已过期'),
      latitude: latitude, longitude: longitude, request_id: 'req_2', latency_ms: 900.0
    )

    expect(events.first).to include(
      request_id: 'req_2', matched: false,
      error_code: :reverse_geocode_refused,
      error_message: a_string_including('此key已过期')
    )
  end
end
