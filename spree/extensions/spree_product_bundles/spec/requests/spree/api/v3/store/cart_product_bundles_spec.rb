require 'spec_helper'

RSpec.describe 'the sets a cart holds', type: :request do
  include_context 'API v3 Store'

  let(:store) { @default_store }
  let(:tea) { create(:product, store: store, seller: nil, price: 60).default_variant }
  let(:cup) { create(:product, store: store, seller: nil, price: 40).default_variant }
  let(:cart) { create(:cart, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }

  let(:bundle) do
    create(:product_bundle, store: store, title: '双人下午茶套餐', components: { tea => 1, cup => 2 }).tap do |record|
      record.preferred_discount_kind = 'amount'
      record.preferred_discount_value = 20
      record.status = 'active'
      record.save!
    end
  end

  # A bundle reaches a cart as its components, each line tagged with the set it
  # belongs to; grouping happens on the line's own write, which is what the
  # subscriber does in a running store.
  def add_bundle(quantity: 1)
    [tea, cup].each do |variant|
      component = bundle.components.find { |row| row.variant_id == variant.id }
      line = create(:line_item, cart: cart, variant: variant, quantity: component.quantity * quantity,
                               price: variant.price_in(store.default_currency).amount,
                               metadata: { 'bundle_id' => bundle.prefixed_id })
      holder = double('Event', name: 'line_item.created', payload: { 'id' => line.prefixed_id })
      Spree::ProductBundles::LineItemSubscriber.new.call(holder)
    end
  end

  it 'answers each set the cart holds, with the lines it was added as' do
    add_bundle

    get "/api/v3/store/carts/#{cart.prefixed_id}/product_bundles", headers: headers

    body = response.parsed_body
    expect(response).to have_http_status(:ok)
    expect(body['data'].size).to eq(1)

    group = body['data'].first
    expect(group['title']).to eq('双人下午茶套餐')
    expect(group['bundle_id']).to eq(bundle.prefixed_id)
    expect(group['quantity']).to eq(1)
    expect(group['goods_price']).to eq(140.0)
    expect(group['saving']).to eq(20.0)
    expect(group['price']).to eq(120.0)
    # The lines are the cart's own, so a client renders them with the serializer
    # it already knows.
    expect(group['line_items'].size).to eq(2)
    expect(group['line_items'].map { |line| line['variant_id'] }).to contain_exactly(tea.prefixed_id, cup.prefixed_id)
  end

  it 'answers the sets a second set makes two of' do
    add_bundle(quantity: 2)

    get "/api/v3/store/carts/#{cart.prefixed_id}/product_bundles", headers: headers

    group = response.parsed_body['data'].first
    expect(group['quantity']).to eq(2)
    expect(group['saving']).to eq(40.0)
    expect(group['price']).to eq(240.0)
  end

  it 'answers nothing for a cart that holds no set' do
    create(:line_item, cart: cart, variant: tea, quantity: 1, price: 60)

    get "/api/v3/store/carts/#{cart.prefixed_id}/product_bundles", headers: headers

    expect(response.parsed_body['data']).to eq([])
  end

  # A cart that is not this caller's is refused rather than read.
  it 'refuses somebody else’s cart' do
    other_cart = create(:cart, store: store)

    get "/api/v3/store/carts/#{other_cart.prefixed_id}/product_bundles", headers: headers

    expect(response).to have_http_status(:forbidden)
  end
end
