require 'spec_helper'

RSpec.describe 'the cart’s promotion choice', type: :request do
  include_context 'API v3 Store'

  let(:store) { @default_store }
  let(:cart) { create(:cart, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }
  let!(:tea) { create(:line_item, cart: cart, quantity: 1, price: 100) }
  let!(:cup) { create(:line_item, cart: cart, quantity: 1, price: 100) }

  let(:weak) { create(:promotion_with_item_adjustment, adjustment_rate: 5, kind: :automatic, store: store) }
  let(:strong) { create(:promotion_with_item_adjustment, adjustment_rate: 30, kind: :automatic, store: store) }

  before do
    weak.activate(order: cart)
    strong.activate(order: cart)
    cart.recalculate_totals!
  end

  def choose(promotion, line_item: nil, code: nil)
    params = { promotion_id: promotion.prefixed_id }
    params[:line_item_id] = line_item.prefixed_id if line_item
    params[:promotion_code] = code if code

    post "/api/v3/store/carts/#{cart.prefixed_id}/promotion_selection", headers: headers, params: params
  end

  # What the picker is drawn from and why it is offered at all: more than one
  # promotion could discount this line.
  it 'offers the promotions that could discount a line, and names the one that did' do
    get "/api/v3/store/carts/#{cart.prefixed_id}", headers: headers

    line = response.parsed_body['items'].find { |item| item['id'] == tea.prefixed_id }
    expect(line['promotion_candidates'].map { |candidate| candidate['id'] }).
      to contain_exactly(weak.prefixed_id, strong.prefixed_id)
    expect(line['promotion_candidates'].map { |candidate| candidate['amount'] }).to contain_exactly('5.0', '30.0')
    # The engine's winner, until the shopper says otherwise.
    expect(line['promotion_id']).to eq(strong.prefixed_id)
  end

  it 'gives the line the promotion the shopper picked, and only that line' do
    choose(weak, line_item: tea)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    chosen = body['items'].find { |item| item['id'] == tea.prefixed_id }
    other = body['items'].find { |item| item['id'] == cup.prefixed_id }

    expect(chosen['promotion_id']).to eq(weak.prefixed_id)
    expect(chosen['discount_total']).to eq('-5.0')
    expect(other['promotion_id']).to eq(strong.prefixed_id)
    expect(other['discount_total']).to eq('-30.0')
    expect(body['discount_total']).to eq('-35.0')
  end

  # A promotion that discounts both lines does not say which one the shopper
  # means, so the write says it instead of guessing.
  it 'refuses a choice that names no line when the promotion applies to several' do
    choose(weak)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to include('more than one line')
  end

  it 'refuses a promotion this cart could not be discounted by' do
    stranger = create(:promotion_with_item_adjustment, adjustment_rate: 50, kind: :automatic, store: store)

    choose(stranger, line_item: tea)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to include('does not apply')
    expect(cart.line_items.first.reload.chosen_promotion_id).to be_nil
  end

  # The code came off the list the client rendered; when it no longer matches
  # the server's, that list is stale and the choice is refused rather than
  # applied to whichever promotion answers to the id today.
  it 'refuses a code that is not the candidate’s own' do
    choose(weak, line_item: tea, code: 'SOMETHING-ELSE')

    expect(response).to have_http_status(:unprocessable_content)
    expect(cart.line_items.first.reload.chosen_promotion_id).to be_nil
  end

  # The choice outlives the request that made it: a later recalculation of the
  # cart — an added line — still gives the chosen line its own promotion.
  it 'keeps the choice through later recalculations' do
    choose(weak, line_item: tea)
    create(:line_item, cart: cart, quantity: 1, price: 50)
    cart.recalculate_totals!

    get "/api/v3/store/carts/#{cart.prefixed_id}", headers: headers

    line = response.parsed_body['items'].find { |item| item['id'] == tea.prefixed_id }
    expect(line['promotion_id']).to eq(weak.prefixed_id)
    expect(line['discount_total']).to eq('-5.0')
  end
end
