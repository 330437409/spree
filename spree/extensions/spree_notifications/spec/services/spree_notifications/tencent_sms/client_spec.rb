require 'spec_helper'

# The client's own half of a send: what it does when the vendor is unreachable
# rather than refusing. The signing is the signer's spec; this one is about the
# calls that never leave the machine.
RSpec.describe SpreeNotifications::TencentSms::Client do
  subject(:client) do
    described_class.new(secret_id: 'AKID', secret_key: 'SECRET', sms_sdk_app_id: '1400000000')
  end

  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  before { allow(client).to receive(:connection).and_raise(Faraday::ConnectionFailed.new('no route to host')) }

  # A vendor that is down must not cost one full timeout per queued message.
  it 'stops calling an account that keeps failing, and says so in its own words' do
    described_class::FAILURE_LIMIT.times do
      expect { client.sign_names }.to raise_error(Faraday::ConnectionFailed)
    end

    expect { client.sign_names }.to raise_error(SpreeNotifications::DeliveryError, /not answering/) do |error|
      expect(error.code).to eq('CircuitOpen')
    end
  end

  it 'closes the circuit again once the window passes' do
    described_class::FAILURE_LIMIT.times do
      expect { client.sign_names }.to raise_error(Faraday::ConnectionFailed)
    end

    Rails.cache.delete(client.send(:failure_key))

    expect { client.sign_names }.to raise_error(Faraday::ConnectionFailed)
  end
end
