require 'spec_helper'

RSpec.describe 'the storefront flash-sale reads', type: :request do
  include_context 'API v3 Store authenticated'

  let(:headers) { bearer_headers }
  let(:flash_sale) { create(:flash_sale, store: store, title: '周末秒杀', pool_all: 10) }
  let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 10) }
  let(:variant) { create(:variant).tap { |record| record.stock_levels.update_all(count_on_hand: 10, backorderable: false) } }
  let!(:item) { create(:flash_sale_item, flash_sale: flash_sale, variant: variant, sale_amount: 9.9, pool: 10, position: 1) }

  before { slot }

  describe 'the list' do
    it 'answers the activities a customer could buy from' do
      get '/api/v3/store/flash_sales', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq([flash_sale.prefixed_id])
    end

    # An ended activity is absent rather than rendered in a third state.
    it 'leaves an activity whose window has closed out of the list' do
      flash_sale.update!(starts_at: 3.hours.ago, ends_at: 1.minute.ago)

      get '/api/v3/store/flash_sales', headers: headers

      expect(response.parsed_body['data']).to eq([])
    end
  end

  describe 'one activity' do
    it 'answers the window, the pool figures and both prices' do
      get "/api/v3/store/flash_sales/#{flash_sale.prefixed_id}", headers: headers

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body['title']).to eq('周末秒杀')
      expect(body['window_status']).to eq('live')
      expect(body['server_now']).to be_present
      expect(body['remaining']).to eq(10)
      expect(body['percentage']).to eq(0)

      goods = body['items'].first
      expect(goods['sale_price']).to eq(9.9)
      expect(goods['price']).to eq(variant.price_in(store.default_currency).amount.to_f)
    end

    it 'answers a claim already made from the pool' do
      Spree::FlashSales::ClaimTicket.call(customer: user, item: item, quantity: 4, slot: slot)

      get "/api/v3/store/flash_sales/#{flash_sale.prefixed_id}", headers: headers

      expect(response.parsed_body['remaining']).to eq(6)
      expect(response.parsed_body['percentage']).to eq(40)
      expect(response.parsed_body['standby_tickets']).to eq(1)
    end
  end

  describe 'the activity a goods is on' do
    it 'answers the activity the buy popup asks about' do
      get "/api/v3/store/flash_sales/by_product/#{variant.product.prefixed_id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(flash_sale.prefixed_id)
    end

    it 'answers 404 for a goods no activity sells' do
      get "/api/v3/store/flash_sales/by_product/#{create(:product, store: store).prefixed_id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
