require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::ItemsBatchesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }
  let(:variant) { create(:variant, product: product, price: 10) }
  let!(:cart) { create(:cart, customer: user, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  # `as: :json` matters: the default form encoding collapses repeated keys
  # across an array of hashes, so a set arrives merged into one entry.
  def write_batch(items)
    post :create, params: { cart_id: cart.prefixed_id, items: items }, as: :json
  end

  it 'writes a set of lines in one request' do
    other_variant = create(:variant, product: create(:product, store: store), price: 20)

    expect do
      write_batch([
                    { variant_id: variant.prefixed_id, quantity: 2 },
                    { variant_id: other_variant.prefixed_id, quantity: 1 }
                  ])
    end.to change(Spree::LineItem, :count).by(2)

    expect(response).to have_http_status(:created)
    expect(json_response['total_quantity']).to eq(3)
    expect(json_response['item_total']).to eq('40.0')
  end

  # The quantities are the set the cart should hold, not an amount to add: a
  # client that retries a batch writes the same cart twice.
  it 'sets the quantity of a line the cart already holds' do
    line_item = create(:line_item, cart: cart, variant: variant, quantity: 1, price: 10)
    cart.recalculate_totals!

    expect do
      write_batch([{ line_item_id: line_item.prefixed_id, quantity: 4 }])
    end.not_to change(Spree::LineItem, :count)

    expect(response).to have_http_status(:created)
    expect(line_item.reload.quantity).to eq(4)

    write_batch([{ line_item_id: line_item.prefixed_id, quantity: 4 }])

    expect(line_item.reload.quantity).to eq(4)
    expect(json_response['total_quantity']).to eq(4)
  end

  it 'writes a set naming a variant and a line together' do
    line_item = create(:line_item, cart: cart, variant: variant, quantity: 1, price: 10)
    other_variant = create(:variant, product: create(:product, store: store), price: 20)

    write_batch([
                  { line_item_id: line_item.prefixed_id, quantity: 3 },
                  { variant_id: other_variant.prefixed_id, quantity: 2 }
                ])

    expect(response).to have_http_status(:created)
    expect(line_item.reload.quantity).to eq(3)
    expect(cart.line_items.count).to eq(2)
  end

  # One recalculation for the whole set is what makes a batch worth having.
  it 'recalculates the cart once for the set' do
    expect(Spree).to receive(:cart_recalculate_workflow).once.and_call_original

    write_batch([
                  { variant_id: variant.prefixed_id, quantity: 1 },
                  { variant_id: create(:variant, product: create(:product, store: store), price: 5).prefixed_id, quantity: 1 }
                ])

    expect(response).to have_http_status(:created)
  end

  # A set is not all-or-nothing: an entry the cart rules refuse comes back as a
  # warning on the cart and the rest of the set still applies.
  it 'reports a rejected entry and writes the rest' do
    Spree.hooks.register('carts.upsert_items.validate') do |workflow|
      next unless workflow.variant == variant

      workflow.errors.add(:base, :purchase_limit_exceeded, message: 'You can order at most 1 of this item.')
      workflow.reject!
    end

    begin
      write_batch([
                    { variant_id: variant.prefixed_id, quantity: 5 },
                    { variant_id: create(:variant, product: create(:product, store: store), price: 5).prefixed_id, quantity: 2 }
                  ])
    ensure
      Spree.hooks.clear!
    end

    expect(response).to have_http_status(:created)
    expect(json_response['warnings'].first['code']).to eq('purchase_limit_exceeded')
    expect(cart.reload.line_items.map(&:variant_id)).not_to include(variant.id)
    expect(cart.total_quantity).to eq(2)
  end

  it 'refuses a batch that names no item' do
    write_batch([])

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['error']['code']).to eq('validation_error')
  end

  it 'refuses a line this cart does not hold' do
    other_line = create(:line_item, cart: create(:cart, store: store), quantity: 1)

    write_batch([{ line_item_id: other_line.prefixed_id, quantity: 2 }])

    expect(response).to have_http_status(:unprocessable_content)
    expect(other_line.reload.quantity).to eq(1)
  end

  # Removals are the DELETE endpoint's: a write that reads as an edit must not
  # delete a line.
  it 'refuses a quantity that is not a positive whole number' do
    create(:line_item, cart: cart, variant: variant, quantity: 1, price: 10)

    write_batch([{ variant_id: variant.prefixed_id, quantity: 0 }])

    expect(response).to have_http_status(:unprocessable_content)
    expect(cart.reload.line_items.count).to eq(1)
  end

  it 'refuses an entry that names neither a variant nor a line' do
    write_batch([{ quantity: 2 }])

    expect(response).to have_http_status(:unprocessable_content)
  end
end
