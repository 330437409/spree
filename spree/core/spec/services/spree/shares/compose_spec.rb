require 'spec_helper'

RSpec.describe Spree::Shares::Compose do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store, name: '青花瓷茶具') }

  # The client's own decoder, written from its source: it splits `typeId` on
  # `_`, turns each `-` into `=`, and joins the parts with `&` — and the page
  # then reads that query through a URL parser, which is where an escaped value
  # comes back as it was written (static/behaviors/locationLinkBehavior.js:7-13).
  def decode(type_id)
    CGI.unescape(type_id.split('_').map { |part| part.split('-').join('=') }.join('&'))
  end

  def compose(target, **options)
    described_class.call(target: target, **options)
  end

  it 'answers the words, the picture and the link a card needs' do
    share = compose(product).value

    expect(share.title).to eq('青花瓷茶具')
    expect(share.path).to start_with('/pages/index?type=inviteGoods&typeId=')
  end

  # The path is the client's grammar, so what it decodes has to be the fields
  # its page opens with — the product, and the shop the link came from.
  it 'encodes the target’s identifiers the way the client decodes them' do
    type_id = compose(product).value.path[/typeId=([^&]+)/, 1]

    expect(decode(type_id)).to eq("id=#{product.prefixed_id}&originalSiteId=#{store.prefixed_id}")
  end

  # The QR and the poster are the identity capability's, and nothing here
  # fetches a token to render them (docs/plans/6.1-store-api-miniprogram-gaps.md).
  it 'leaves the QR, the poster and the scene to the capability that owns them' do
    share = compose(product).value

    expect(share.scene).to be_nil
    expect(share.qrcode_url).to be_nil
    expect(share.poster_url).to be_nil
  end

  # A model that does not answer the contract is not shareable, whatever the
  # request called it.
  it 'refuses a target that does not answer the contract' do
    result = compose(store)

    expect(result).to be_failure
    expect(result.error.value).to eq(:not_shareable)
  end
end
