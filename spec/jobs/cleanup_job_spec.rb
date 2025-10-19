require 'rails_helper'

RSpec.describe CleanupJob, type: :job do
  it 'purges expired jwt blacklist entries' do
    # Create expired and active entries
    JwtBlacklist.create!(jti: SecureRandom.uuid, token_type: 'access', expires_at: 1.hour.ago)
    active = JwtBlacklist.create!(jti: SecureRandom.uuid, token_type: 'refresh', expires_at: 1.hour.from_now)

    expect(JwtBlacklist.count).to eq(2)
    described_class.new.perform
    expect(JwtBlacklist.count).to eq(1)
    expect(JwtBlacklist.first.id).to eq(active.id)
  end
end
