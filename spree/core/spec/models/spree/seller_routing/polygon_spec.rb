require 'spec_helper'

RSpec.describe Spree::SellerRouting::Polygon, type: :model do
  # A square around 东城区. GeoJSON's right-hand rule wants the outline
  # counter-clockwise, which is what the first one is; `clockwise` is the same
  # ring drawn the other way round, and is the canonicalisation case below.
  let(:counter_clockwise_square) do
    [[[116.40, 39.96], [116.40, 39.90], [116.44, 39.90], [116.44, 39.96], [116.40, 39.96]]]
  end

  let(:clockwise_square) { counter_clockwise_square.map(&:reverse) }

  describe 'usable geometry' do
    it 'accepts a closed ring of four or more points' do
      expect(described_class.new(counter_clockwise_square)).to be_valid
    end

    it 'accepts rings that arrived as JSON from a json column' do
      expect(described_class.new(JSON.generate(counter_clockwise_square))).to be_valid
    end

    it 'refuses a ring with fewer than four points' do
      triangle_of_two = [[[116.40, 39.96], [116.40, 39.90], [116.40, 39.96]]]

      expect(described_class.new(triangle_of_two).errors).to include(attribute: :polygon, error: :too_few_points)
    end

    it 'refuses a ring that does not close' do
      open_ring = [counter_clockwise_square.first[0..-2]]

      expect(described_class.new(open_ring).errors).to include(attribute: :polygon, error: :not_closed)
    end

    it 'refuses a coordinate that is not a pair of numbers' do
      malformed = [[[116.40, 39.96], [116.40], [116.44, 39.90], [116.44, 39.96], [116.40, 39.96]]]

      expect(described_class.new(malformed).errors).to include(attribute: :polygon, error: :not_a_point)
    end

    it 'refuses a coordinate that is not finite' do
      infinite = [[[116.40, 39.96], [Float::INFINITY, 39.90], [116.44, 39.90], [116.44, 39.96], [116.40, 39.96]]]

      expect(described_class.new(infinite).errors).to include(attribute: :polygon, error: :not_a_point)
    end

    it 'refuses a coordinate off the map' do
      off_the_map = [[[116.40, 39.96], [116.40, 139.90], [116.44, 39.90], [116.44, 39.96], [116.40, 39.96]]]

      expect(described_class.new(off_the_map).errors).to include(attribute: :polygon, error: :out_of_range)
    end

    it 'refuses a ring that crosses itself' do
      bow_tie = [[[116.40, 39.90], [116.44, 39.96], [116.44, 39.90], [116.40, 39.96], [116.40, 39.90]]]

      expect(described_class.new(bow_tie).errors).to include(attribute: :polygon, error: :self_intersecting)
    end
  end

  describe 'winding' do
    it 'turns a clockwise outline counter-clockwise rather than refusing it' do
      polygon = described_class.new(clockwise_square)

      expect(polygon).to be_valid
      expect(polygon.canonicalized).to eq(counter_clockwise_square)
    end

    it 'leaves an outline that is already counter-clockwise alone' do
      polygon = described_class.new(counter_clockwise_square)

      expect(polygon.canonicalized).to eq(counter_clockwise_square)
    end
  end

  describe 'the bounding box' do
    it 'answers the extremes of every ring' do
      expect(described_class.new(counter_clockwise_square).bounding_box).to eq(
        min_lng: 116.40, max_lng: 116.44, min_lat: 39.90, max_lat: 39.96
      )
    end

    it 'contains the points inside it and not the ones outside' do
      polygon = described_class.new(counter_clockwise_square)

      expect(polygon.bounding_box_contains?(latitude: 39.93, longitude: 116.42)).to be true
      expect(polygon.bounding_box_contains?(latitude: 40.10, longitude: 116.42)).to be false
    end
  end

  describe 'containment' do
    let(:polygon) { described_class.new(counter_clockwise_square) }

    it 'holds a point inside the outline' do
      expect(polygon.contains?(latitude: 39.93, longitude: 116.42)).to be true
    end

    it 'rejects a point outside it' do
      expect(polygon.contains?(latitude: 39.93, longitude: 116.50)).to be false
      expect(polygon.contains?(latitude: 40.10, longitude: 116.42)).to be false
    end

    it 'excludes a point inside a hole' do
      with_hole = [
        counter_clockwise_square.first,
        [[116.41, 39.94], [116.43, 39.94], [116.43, 39.92], [116.41, 39.92], [116.41, 39.94]]
      ]

      expect(described_class.new(with_hole).contains?(latitude: 39.93, longitude: 116.42)).to be false
      expect(described_class.new(with_hole).contains?(latitude: 39.905, longitude: 116.405)).to be true
    end
  end
end
