require 'rails_helper'

RSpec.describe JsonWebToken do
  it 'encodes and decodes payload and handles exp' do
    token = described_class.encode({ foo: 'bar' }, 1.hour.from_now)
    payload = described_class.decode(token)
    expect(payload[:foo]).to eq('bar')
    expect(payload[:exp]).to be_present
  end

  it 'returns nil for invalid token' do
    expect(described_class.decode('bogus')).to be_nil
  end

  it 'returns nil when expired' do
    token = described_class.encode({ foo: 'bar' }, 1.second.from_now)
    sleep 2
    expect(described_class.decode(token)).to be_nil
  end
end
