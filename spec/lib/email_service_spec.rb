require 'rails_helper'

RSpec.describe EmailService do
  let(:recipient) { 'to@example.com' }
  let(:template_name) { 'welcome' }
  let(:context) { { name: 'Jane' } }

  before do
    # Default from used by the mailer
    allow(UserMailer).to receive(:default).and_return({ from: 'default@example.com' })
    allow(Rails.logger).to receive(:error) # silence error logs in specs
  end

  describe '.send_email' do
    it 'returns nil when to is blank' do
      expect(UserMailer).not_to receive(:send_template_email)
      result = described_class.send_email(to: nil, template_name: template_name)
      expect(result).to be_nil
    end

    it 'returns nil when template_name is blank' do
      expect(UserMailer).not_to receive(:send_template_email)
      result = described_class.send_email(to: recipient, template_name: nil)
      expect(result).to be_nil
    end

    it 'sends email async by default, sets subject and from when overridden' do
      mail = double('Mail::Message', subject: nil, from: nil)
      expect(UserMailer).to receive(:send_template_email).with(recipient, template_name, hash_including(name: 'Jane')).and_return(mail)
      expect(mail).to receive(:subject=).with('Hello')
      expect(mail).to receive(:from=).with('override@example.com')
      expect(mail).to receive(:deliver_later).and_return(:queued)

      result = described_class.send_email(
        to: recipient,
        template_name: template_name,
        context: context,
        subject: 'Hello',
        from: 'override@example.com'
      )
      expect(result).to eq(:queued)
    end

    it 'sends email sync when async: false and does not override subject/from when not provided or equal to default' do
      mail = double('Mail::Message')
      expect(UserMailer).to receive(:send_template_email).with(recipient, template_name, {}).and_return(mail)
      expect(mail).not_to receive(:subject=)
      expect(mail).not_to receive(:from=)
      expect(mail).to receive(:deliver_now).and_return(:sent)

      result = described_class.send_email(to: recipient, template_name: template_name, context: {}, async: false)
      expect(result).to eq(:sent)
    end

    it 'returns nil when mailer returns nil (template missing)' do
      expect(UserMailer).to receive(:send_template_email).and_return(nil)
      result = described_class.send_email(to: recipient, template_name: template_name)
      expect(result).to be_nil
    end

    it 'rescues exceptions and logs error, returning nil' do
      expect(UserMailer).to receive(:send_template_email).and_raise(StandardError.new('boom'))
      expect(Rails.logger).to receive(:error) # logger called with block
      result = described_class.send_email(to: recipient, template_name: template_name, context: context)
      expect(result).to be_nil
    end
  end

  describe '.send_bulk_email' do
    it 'sends to multiple recipients and returns results, skipping blanks' do
      mail1 = double('Mail::Message')
      mail2 = double('Mail::Message')
      expect(UserMailer).to receive(:send_template_email).with('a@x.com', template_name, {}).and_return(mail1)
      expect(UserMailer).to receive(:send_template_email).with('b@y.com', template_name, {}).and_return(mail2)
      expect(mail1).to receive(:deliver_later).and_return(:q1)
      expect(mail2).to receive(:deliver_later).and_return(:q2)

      results = described_class.send_bulk_email(recipients: ['a@x.com', '', nil, 'b@y.com'], template_name: template_name, context: {})
      expect(results).to eq([:q1, :q2])
    end

    it 'respects options (e.g., async: false) for each recipient' do
      mail1 = double('Mail::Message')
      mail2 = double('Mail::Message')
      allow(UserMailer).to receive(:send_template_email).and_return(mail1, mail2)
      expect(mail1).to receive(:deliver_now).and_return(:s1)
      expect(mail2).to receive(:deliver_now).and_return(:s2)

      results = described_class.send_bulk_email(recipients: %w[a@x.com b@y.com], template_name: template_name, context: {}, async: false)
      expect(results).to eq([:s1, :s2])
    end

    it 'filters out nil results from send_email (e.g., template missing)' do
      allow(UserMailer).to receive(:send_template_email).and_return(nil, double('Mail::Message', deliver_later: :ok))
      results = described_class.send_bulk_email(recipients: %w[a@x.com b@y.com], template_name: template_name)
      expect(results).to eq([:ok])
    end
  end

  describe 'default from behavior' do
    it 'uses fallback support from when UserMailer.default[:from] is nil' do
      allow(UserMailer).to receive(:default).and_return({ from: nil })
      mail = double('Mail::Message')
      expect(UserMailer).to receive(:send_template_email).and_return(mail)
      expect(mail).to receive(:from=).with('support@mail.karya-app.com')
      allow(mail).to receive(:deliver_later)
      described_class.send_email(to: recipient, template_name: template_name)
    end

    it 'does not set from when computed from equals UserMailer.default[:from]' do
      allow(UserMailer).to receive(:default).and_return({ from: 'support@mail.karya-app.com' })
      mail = double('Mail::Message')
      expect(UserMailer).to receive(:send_template_email).and_return(mail)
      expect(mail).not_to receive(:from=)
      allow(mail).to receive(:deliver_later)
      described_class.send_email(to: recipient, template_name: template_name)
    end
  end
end
