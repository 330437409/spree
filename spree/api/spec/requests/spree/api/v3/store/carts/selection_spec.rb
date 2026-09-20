require 'spec_helper'

RSpec.describe 'the cart’s selection', type: :request do
  include_context 'API v3 Store'

  let(:store) { @default_store }
  let(:cart) { create(:cart, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }
  let!(:tea) { create(:line_item, cart: cart, quantity: 2, price: 60) }
  let!(:cup) { create(:line_item, cart: cart, quantity: 1, price: 40) }

  # The cart's own quantity is a counter its totals workflow maintains; a spec
  # that builds lines directly has to ask for it once.
  before { cart.recalculate_totals! }

  def select_lines(lines, selected:)
    patch "/api/v3/store/carts/#{cart.prefixed_id}/selection",
          headers: headers,
          params: { selected: selected, line_item_ids: lines.map(&:prefixed_id) }
  end

  # A line is ticked when it is added: an unticked line is the shopper's choice,
  # not the default state.
  it 'starts with every line selected' do
    get "/api/v3/store/carts/#{cart.prefixed_id}", headers: headers

    body = response.parsed_body
    expect(body['items'].map { |line| line['selected'] }).to eq([true, true])
    expect(body['selected_quantity']).to eq(3)
    expect(body['total_quantity']).to eq(3)
  end

  it 'untick one line and answers the cart with what is left chosen' do
    select_lines([tea], selected: false)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['items'].find { |line| line['id'] == tea.prefixed_id }['selected']).to be(false)
    expect(body['selected_quantity']).to eq(1)
    # The cart still holds everything: the selection is which of it is being
    # bought, not a second cart.
    expect(body['total_quantity']).to eq(3)
  end

  # The client ticks a whole group at once, and one write carries all of it.
  it 'write over several lines at once' do
    select_lines([tea, cup], selected: false)

    expect(response.parsed_body['selected_quantity']).to eq(0)
  end

  # A tick is an input to the cart's money, not a filter over it: the same
  # request that writes the ticks answers with the chosen lines' money, so a
  # cart page and a settle page read one figure rather than two.
  it 'answers with the money of the chosen lines' do
    select_lines([tea], selected: false)

    body = response.parsed_body
    expect(body['item_total']).to eq('40.0')
    expect(body['total']).to eq('40.0')
    expect(body['selected_quantity']).to eq(1)
  end

  it 'ignores a line the cart does not hold' do
    other_line = create(:line_item, cart: create(:cart, store: store))

    select_lines([tea, other_line], selected: false)

    expect(response).to have_http_status(:ok)
    expect(other_line.reload.selected).to be(true)
  end

  # A write has to say which way to go. An absent value is not "false", and
  # writing nil into a column that forbids it would answer a client's mistake
  # with a server fault.
  it 'refuses a write that does not say whether to select or deselect' do
    patch "/api/v3/store/carts/#{cart.prefixed_id}/selection",
          headers: headers,
          params: { line_item_ids: [tea.prefixed_id] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(tea.reload.selected).to be(true)
  end

  it 'refuses a write that names no line' do
    patch "/api/v3/store/carts/#{cart.prefixed_id}/selection",
          headers: headers,
          params: { selected: true, line_item_ids: [] }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'refuses somebody else’s cart' do
    patch "/api/v3/store/carts/#{create(:cart, store: store).prefixed_id}/selection",
          headers: headers,
          params: { selected: false, line_item_ids: [tea.prefixed_id] }

    expect(response).to have_http_status(:forbidden)
  end
end
