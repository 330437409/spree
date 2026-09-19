require 'spec_helper'

RSpec.describe 'the flash-sale ticket endpoints', type: :request do
  include_context 'API v3 Store authenticated'

  let(:headers) { bearer_headers }
  let(:flash_sale) { create(:flash_sale, store: store, pool_all: 10, pool_per_day: 10, pool_per_slot: 10) }
  let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 10) }
  let(:variant) { create(:variant).tap { |record| record.stock_levels.update_all(count_on_hand: 10, backorderable: false) } }
  let!(:item) { create(:flash_sale_item, flash_sale: flash_sale, variant: variant, sale_amount: 9.9, pool: 10) }

  before { slot }

  def claim(quantity: 1, **overrides)
    post '/api/v3/store/flash_sale_tickets',
         params: { flash_sale_id: flash_sale.prefixed_id, variant_id: variant.prefixed_id,
                   flash_sale_slot_id: slot.prefixed_id, quantity: quantity }.merge(overrides),
         headers: headers
  end

  describe 'claiming' do
    it 'gives the customer a ticket holding the units' do
      claim(quantity: 2)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['quantity']).to eq(2)
      expect(response.parsed_body['status']).to eq('holding')
      expect(response.parsed_body['expires_at']).to be_present
      expect(response.parsed_body['flash_sale_slot_id']).to eq(slot.prefixed_id)
    end

    # A refusal is an answer: the client switches on the reason and shows the
    # message its own dialog has for that case.
    it 'answers the reason a claim was refused' do
      flash_sale.update!(pool_all: 1)

      claim(quantity: 2)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['details']['reason']).to eq('sold_out')
      expect(response.parsed_body['error']['message']).to be_present
    end

    it 'replaces the ticket it is told to replace' do
      claim(quantity: 2)
      first = response.parsed_body['id']

      claim(quantity: 3, replacing_ticket_id: first)

      expect(response).to have_http_status(:created)
      expect(Spree::FlashSaleTicket.holding.count).to eq(1)
      expect(Spree::FlashSaleTicket.find_by_prefix_id(first).status).to eq('replaced')
    end

    it 'refuses a claim from a customer who is not signed in' do
      post '/api/v3/store/flash_sale_tickets',
           params: { flash_sale_id: flash_sale.prefixed_id, variant_id: variant.prefixed_id, quantity: 1 },
           headers: api_key_headers

      expect(response).to have_http_status(:unauthorized)
      expect(Spree::FlashSaleTicket.holding.count).to eq(0)
    end

    it 'answers 404 for an activity this store does not have' do
      claim(flash_sale_id: create(:flash_sale, store: create(:store)).prefixed_id)

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a goods the activity does not sell' do
      claim(variant_id: create(:variant).prefixed_id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['details']['reason']).to eq('not_in_activity')
    end
  end

  describe 'what a customer holds' do
    it 'lists the unpaid tickets with their deadlines' do
      claim(quantity: 1)

      get '/api/v3/store/customers/me/flash_sale_tickets', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].length).to eq(1)
      expect(response.parsed_body['data'].first['expires_at']).to be_present
    end

    it 'leaves out another customer’s tickets' do
      create(:flash_sale_ticket, store: store, flash_sale: flash_sale, variant: variant,
                                 flash_sale_slot: slot, customer: create(:customer), status: 'holding')

      get '/api/v3/store/customers/me/flash_sale_tickets', headers: headers

      expect(response.parsed_body['data']).to eq([])
    end
  end

  describe '开售提醒' do
    def remind
      post "/api/v3/store/flash_sale_slots/#{slot.prefixed_id}/reminders", headers: headers
    end

    it 'remembers a customer waiting for a stretch to open' do
      remind

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['waiting']).to be(true)
      expect(Spree::FlashSale::Reminder.where(flash_sale_slot: slot, customer: user).count).to eq(1)
    end

    it 'asks once however many times it is called' do
      remind
      remind

      expect(Spree::FlashSale::Reminder.where(flash_sale_slot: slot, customer: user).count).to eq(1)
    end

    it 'takes the wait back' do
      remind

      delete "/api/v3/store/flash_sale_slots/#{slot.prefixed_id}/reminders", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Spree::FlashSale::Reminder.where(flash_sale_slot: slot, customer: user).count).to eq(0)
    end
  end
end
