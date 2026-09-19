require 'spec_helper'

RSpec.describe Spree::ReverseGeocode::Geohash do
  it 'encodes a known point to the cell every implementation agrees on' do
    expect(described_class.encode(latitude: 57.64911, longitude: 10.40744)).to eq('u4pruyd')
  end

  it 'gives two customers on the same street the same cell' do
    corner = described_class.encode(latitude: 39.9075, longitude: 116.39723)
    across_the_road = described_class.encode(latitude: 39.9076, longitude: 116.39729)

    expect(across_the_road).to eq(corner)
  end

  it 'separates two points a district apart' do
    expect(described_class.encode(latitude: 39.9075, longitude: 116.39723)).
      not_to eq(described_class.encode(latitude: 39.9675, longitude: 116.45723))
  end

  it 'answers as many characters as it was asked for' do
    expect(described_class.encode(latitude: 39.9075, longitude: 116.39723, precision: 4).length).to eq(4)
  end
end
