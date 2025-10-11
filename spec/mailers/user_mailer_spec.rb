require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe '#send_template_email' do
    let(:recipient) { 'to@example.com' }

    it 'returns nil when template not found' do
      mail = described_class.new.send_template_email(recipient, 'missing_template', {})
      expect(mail).to be_nil
    end

    it 'renders and returns mail when view template exists' do
      template = EmailTemplate.create!(name: 'welcome', subject: 'Welcome Subject', body: nil)
      mailer = described_class.new

      # Pretend the view exists and stub render to avoid MissingTemplate
      allow(mailer.lookup_context).to receive(:exists?).with('welcome', ['email_templates'], false, [:html]).and_return(true)
      allow(mailer).to receive(:render).with('email_templates/welcome').and_return('<h1>Welcome</h1>')

      mail = mailer.send_template_email(recipient, template.name, { name: 'John' })
      expect(mail).to be_a(Mail::Message)
      expect(mail.to).to include(recipient)
      expect(mail.subject).to eq('Welcome Subject')
      expect(mail.body.encoded).to include('Welcome')
    end

    it 'renders HTML from template body when view does not exist but body present' do
      template = EmailTemplate.create!(name: 'raw_body', subject: 'Body Subject', body: '<p>Hello Body</p>')
      mailer = described_class.new

      allow(mailer.lookup_context).to receive(:exists?).with('raw_body', ['email_templates'], false, [:html]).and_return(false)

      mail = mailer.send_template_email(recipient, template.name, { any: 'var' })
      expect(mail).to be_a(Mail::Message)
      expect(mail.to).to include(recipient)
      expect(mail.subject).to eq('Body Subject')
      expect(mail.body.encoded).to include('Hello Body')
    end

    it 'returns nil when template has no view and empty body' do
      template = EmailTemplate.create!(name: 'empty', subject: 'Empty Subject', body: nil)
      mailer = described_class.new

      lookup = double('lookup_context')
      allow(mailer).to receive(:lookup_context).and_return(lookup)
      expect(lookup).to receive(:exists?).with('empty', ['email_templates'], false, [:html]).and_return(false)

      mail = mailer.send_template_email(recipient, template.name, {})
      expect(mail).to be_nil
    end
  end
end
