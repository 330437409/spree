require 'spec_helper'

RSpec.describe Spree::ProductBundles::LineItemSubscriber do
  let(:store) { Spree::Store.default || create(:store, default: true) }
  let(:tea) { create(:product, store: store, seller: nil, price: 60).default_variant }
  let(:cup) { create(:product, store: store, seller: nil, price: 40).default_variant }
  let(:cart) { create(:cart, store: store) }
  let(:subscriber) { described_class.new }

  let(:bundle) do
    create(:product_bundle, store: store, title: '双人下午茶套餐', components: { tea => 1, cup => 2 }).tap do |record|
      record.preferred_discount_kind = 'amount'
      record.preferred_discount_value = 20
      record.status = 'active'
      record.save!
    end
  end

  def event_for(record, name)
    double('Event', name: name, payload: { 'id' => record.prefixed_id })
  end

  def add_line(variant, quantity:, bundle_id: nil)
    create(:line_item, cart: cart, variant: variant, quantity: quantity,
                       price: variant.price_in(store.default_currency).amount,
                       metadata: bundle_id ? { 'bundle_id' => bundle_id } : {})
  end

  def handle(line_item, name = 'line_item.created')
    subscriber.call(event_for(line_item, name))
  end

  # Adding a bundle writes the components as ordinary lines; the tag on each
  # line is what makes them a set.
  it 'groups the lines a bundle was added as' do
    tea_line = add_line(tea, quantity: 1, bundle_id: bundle.prefixed_id)
    cup_line = add_line(cup, quantity: 2, bundle_id: bundle.prefixed_id)

    handle(tea_line)
    handle(cup_line)

    expect(Spree::BundleLineItem.where(owner: cart).count).to eq(2)
    expect(Spree::BundleLineItem.find_by(line_item: tea_line).bundle).to eq(bundle)
  end

  # What the set saves, as one row per component line, allocated in proportion
  # to what each costs.
  it 'writes the saving over the set’s own lines' do
    tea_line = add_line(tea, quantity: 1, bundle_id: bundle.prefixed_id)
    cup_line = add_line(cup, quantity: 2, bundle_id: bundle.prefixed_id)

    handle(tea_line)
    handle(cup_line)

    expect(cart.reload.discounts.sum(:amount).to_d).to eq(-20)
    expect(cart.total.to_d).to eq(120)
    expect(cart.discounts.find_by(line_item: tea_line).amount.to_d).to eq(-8.57)
    expect(cart.discounts.find_by(line_item: cup_line).amount.to_d).to eq(-11.43)
  end

  it 'does not stack a second saving when it runs again' do
    tea_line = add_line(tea, quantity: 1, bundle_id: bundle.prefixed_id)
    cup_line = add_line(cup, quantity: 2, bundle_id: bundle.prefixed_id)

    2.times do
      handle(tea_line)
      handle(cup_line)
    end

    expect(cart.reload.discounts.count).to eq(2)
    expect(cart.total.to_d).to eq(120)
  end

  it 'leaves an ordinary line alone' do
    line = add_line(tea, quantity: 1)

    handle(line)

    expect(Spree::BundleLineItem.count).to eq(0)
    expect(cart.reload.discounts.count).to eq(0)
  end

  # A tag naming something this storefront does not sell is not a set.
  it 'ignores a tag for a bundle that is not on sale' do
    bundle.update!(status: 'archived')
    line = add_line(tea, quantity: 1, bundle_id: bundle.prefixed_id)

    handle(line)

    expect(Spree::BundleLineItem.count).to eq(0)
  end

  it 'ignores a tag on a goods the bundle does not hold' do
    other = create(:product, store: store, seller: nil, price: 10).default_variant
    line = add_line(other, quantity: 1, bundle_id: bundle.prefixed_id)

    handle(line)

    expect(Spree::BundleLineItem.count).to eq(0)
  end

  # A component the customer removed takes its group row with it, and the set it
  # no longer completes stops saving anything.
  it 'ungroups the lines when a component line goes' do
    tea_line = add_line(tea, quantity: 1, bundle_id: bundle.prefixed_id)
    cup_line = add_line(cup, quantity: 2, bundle_id: bundle.prefixed_id)

    handle(tea_line)
    handle(cup_line)
    expect(cart.reload.discounts.count).to eq(2)

    event = event_for(cup_line, 'line_item.destroyed')
    cup_line.destroy!

    subscriber.call(event)

    expect(Spree::BundleLineItem.count).to eq(1)
    expect(cart.reload.discounts.count).to eq(0)
    expect(cart.total.to_d).to eq(60)
  end
end
