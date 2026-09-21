require 'spec_helper'

# Held against Tencent's own worked example (签名方法 v3, the `DescribeInstances`
# call): the payload hash and the canonical request's hash are the two values
# the documentation prints in full. The derived key chain below them cannot be
# checked the same way — the doc masks both credentials — so what is asserted
# here is that the canonical request is byte-identical to theirs, which is the
# half a signature actually goes wrong in.
RSpec.describe SpreeNotifications::TencentSms::Signer do
  subject(:signer) { described_class.new(secret_id: 'AKIDEXAMPLE', secret_key: 'SECRETEXAMPLE') }

  # The documentation's own payload, whose 未命名 is printed as an escape
  # sequence — and the hash it publishes is of those bytes, not of the
  # characters. Built from code points so no editor or shell re-encodes it.
  let(:body) do
    escaped = [0x672a, 0x547d, 0x540d].map { |point| '\\u%04x' % point }.join

    %({"Limit": 1, "Filters": [{"Values": ["#{escaped}"], "Name": "instance-name"}]})
  end
  let(:timestamp) { 1551113065 }
  let(:date) { '2019-02-25' }

  let(:canonical_request) do
    signer.canonical_request(
      action: 'DescribeInstances', body: body,
      content_type: 'application/json; charset=utf-8', host: 'cvm.tencentcloudapi.com'
    )
  end

  it 'hashes the documented payload as the documentation does' do
    expect(Digest::SHA256.hexdigest(body)).to eq('35e9c5b0e3ae67532d3c9f17ead6c90222632e5b1ff7f6e89887f1398934f064')
  end

  it 'builds the documented canonical request' do
    expect(canonical_request).to eq(<<~REQUEST.chomp)
      POST
      /

      content-type:application/json; charset=utf-8
      host:cvm.tencentcloudapi.com
      x-tc-action:describeinstances

      content-type;host;x-tc-action
      35e9c5b0e3ae67532d3c9f17ead6c90222632e5b1ff7f6e89887f1398934f064
    REQUEST
  end

  it 'hashes the canonical request as the documentation does' do
    expect(Digest::SHA256.hexdigest(canonical_request))
      .to eq('7019a55be8395899b900fb5564e4200d984910f34794a27cb3fb7d10ff6a1e84')
  end

  it 'signs the string the documentation signs' do
    string = signer.string_to_sign(canonical_request: canonical_request, date: date, timestamp: timestamp,
                                   service: 'cvm')

    expect(string).to eq(<<~STRING.chomp)
      TC3-HMAC-SHA256
      1551113065
      2019-02-25/cvm/tc3_request
      7019a55be8395899b900fb5564e4200d984910f34794a27cb3fb7d10ff6a1e84
    STRING
  end

  # The secret is what the doc withholds, so the chain is asserted by its
  # contract: a hex digest, different for a different secret, stable for the
  # same one.
  it 'derives a signature from the secret' do
    string = signer.string_to_sign(canonical_request: canonical_request, date: date, timestamp: timestamp, service: 'cvm')

    signature = signer.signature(string_to_sign: string, date: date, service: 'cvm')
    expect(signature).to match(/\A[0-9a-f]{64}\z/)
    expect(signature).to eq(signer.signature(string_to_sign: string, date: date, service: 'cvm'))

    other = described_class.new(secret_id: 'AKIDEXAMPLE', secret_key: 'OTHER')
    expect(other.signature(string_to_sign: string, date: date, service: 'cvm')).not_to eq(signature)
  end

  it 'sends the headers the API expects, with the action in its documented casing' do
    headers = signer.headers(action: 'SendSms', body: '{}', timestamp: timestamp)

    expect(headers['X-TC-Action']).to eq('SendSms')
    expect(headers['X-TC-Timestamp']).to eq('1551113065')
    expect(headers['Host']).to eq('sms.tencentcloudapi.com')
    expect(headers['Authorization']).to include('TC3-HMAC-SHA256 Credential=AKIDEXAMPLE/2019-02-25/sms/tc3_request')
    expect(headers['Authorization']).not_to include('TC3-HMAC-SHA256, ')
    expect(headers['Authorization']).to include('SignedHeaders=content-type;host;x-tc-action')
  end
end
