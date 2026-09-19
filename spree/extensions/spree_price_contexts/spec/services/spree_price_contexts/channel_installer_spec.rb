require 'spec_helper'

RSpec.describe SpreePriceContexts::ChannelInstaller do
  let(:store) { create(:store) }

  def install
    described_class.call(store: store)
  end

  it 'creates the three context channels, by the codes the client sends' do
    expect { install }.to change { store.channels.count }.by(3)

    expect(store.channels.pluck(:code)).to include('area', 'scene', 'offline')
  end

  it 'names them in the store’s own admin locale' do
    store.update!(preferred_admin_locale: 'zh-CN')

    install

    expect(store.channels.find_by(code: 'area').name).to eq('区域')
    expect(store.channels.find_by(code: 'offline').name).to eq('线下')
  end

  # A missing translation returns its own "translation missing: …" string
  # rather than raising, which would end up stored as a channel's name.
  it 'falls back to the application default for a locale it has no file for' do
    store.update!(preferred_admin_locale: 'de')

    install

    expect(store.channels.find_by(code: 'area').name).to eq('Area price')
  end

  it 'leaves a channel that is already there exactly as the operator named it' do
    existing = store.channels.create!(code: 'area', name: '城南区')

    result = install

    expect(existing.reload.name).to eq('城南区')
    expect(result[:created]).to contain_exactly('scene', 'offline')
    expect(result[:existing]).to eq(['area'])
  end

  it 'has nothing to do on a second run' do
    install

    expect { install }.not_to change { store.channels.count }
    expect(described_class.call(store: store)[:created]).to be_empty
  end

  it 'gives each store its own channels' do
    other = create(:store)

    install
    described_class.call(store: other)

    expect(other.channels.pluck(:code)).to include('area', 'scene', 'offline')
  end
end
