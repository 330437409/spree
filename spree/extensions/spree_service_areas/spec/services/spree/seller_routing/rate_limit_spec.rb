require 'spec_helper'

RSpec.describe Spree::SellerRouting::RateLimit do
  around do |example|
    store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = store
  end

  def allow_call(key: 'a-key')
    described_class.allow?(key: key, limit: 3, window: 1.minute)
  end

  it 'allows calls up to the limit' do
    expect(3.times.map { allow_call }).to eq([true, true, true])
  end

  it 'refuses the call after it' do
    3.times { allow_call }

    expect(allow_call).to be false
  end

  it 'counts each caller separately' do
    3.times { allow_call(key: 'one') }

    expect(allow_call(key: 'one')).to be false
    expect(allow_call(key: 'another')).to be true
  end

  it 'starts counting again once the window has passed' do
    3.times { allow_call }

    Timecop.travel(61.seconds.from_now) do
      expect(allow_call).to be true
    end
  end

  context 'with a cache that cannot count' do
    before do
      allow(Rails.cache).to receive(:increment).and_return(nil)
    end

    it 'allows the call rather than taking the endpoint down with it' do
      expect(allow_call).to be true
    end
  end

  context 'with a cache that does not know how to count' do
    before do
      allow(Rails.cache).to receive(:increment).and_raise(NotImplementedError)
    end

    it 'allows the call rather than taking the endpoint down with it' do
      expect(allow_call).to be true
    end
  end
end
