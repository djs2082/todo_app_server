require 'rails_helper'

RSpec.describe 'EventsMap wiring' do
  before do
    # Reset subscription queue and reload the events_map to re-register subscriptions
    Events.queue = Hash.new { |h, k| h[k] = {} }
    load Rails.root.join('lib/events_map.rb')
  end

  describe 'subscriptions' do
    it 'subscribes User to :user_signed_up with :send_activation_email' do
      expect(Events.queue[:user_signed_up][User]).to eq(:send_activation_email)
    end

    it 'reflects Event::EVENTS_LIST wiring (empty by default)' do
      expect(Event::EVENTS_LIST).to be_a(Array)
      expect(Event::EVENTS_LIST).to be_empty
    end
  end

  describe 'User.send_activation_email' do
    let(:user) do
      # Unsaved user to avoid after_commit side effects; set minimal attributes needed by the method
      u = User.new(first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com')
      u.activation_token = 'tok123'
      u
    end

    it 'does nothing when user is nil' do
      expect(EmailService).not_to receive(:send_email)
      User.send_activation_email(:user_signed_up, nil)
    end

    it 'enqueues email with proper template and context using ENV base URL when present' do
      prev = ENV['WEB_APP_BASE_URL']
      ENV['WEB_APP_BASE_URL'] = 'http://test.app'
      begin
        expect(EmailService).to receive(:send_email).with(
          hash_including(
            to: 'jane@example.com',
            template_name: 'account_activation',
            context: hash_including(
              first_name: 'Jane',
              activation_url: 'http://test.app/activate/tok123'
            ),
            async: false
          )
        )
        User.send_activation_email(:user_signed_up, user)
      ensure
        ENV['WEB_APP_BASE_URL'] = prev
      end
    end

    it 'falls back to localhost base URL when ENV is not set' do
      prev = ENV['WEB_APP_BASE_URL']
      ENV.delete('WEB_APP_BASE_URL')
      begin
        expect(EmailService).to receive(:send_email).with(
          hash_including(
            context: hash_including(
              activation_url: 'http://localhost:8000/activate/tok123'
            )
          )
        )
        User.send_activation_email(:user_signed_up, user)
      ensure
        ENV['WEB_APP_BASE_URL'] = prev if prev
      end
    end
  end

  describe 'Event.create_event' do
    let(:subject_user) do
      User.create!(first_name: 'Sub', last_name: 'Ject', email: 'sub@example.com', account_name: 'subject', password: 'secret123', password_confirmation: 'secret123')
    end

    it 'passes initiator_type System when initiator is a system hash' do
      expect(Event).to receive(:create!) do |attrs|
        expect(attrs[:kind]).to eq('user_signed_up')
        expect(attrs[:subject]).to eq(subject_user)
        expect(attrs[:initiator_type]).to eq('System')
        expect(attrs[:message]).to be_a(Hash)
        expect(attrs[:message]['detail']).to eq('info')
      end
      Event.create_event('user_signed_up', subject_user, { name: 'System' }, { detail: 'info' })
    end

    it 'creates event with user initiator when initiator is a model instance' do
      initiator = User.create!(first_name: 'Ini', last_name: 'Tiator', email: 'ini@example.com', account_name: 'initiator', password: 'secret123', password_confirmation: 'secret123')

      expect {
        Event.create_event('task_created', subject_user, initiator, { title: 'Made' })
      }.to change(Event, :count).by(1)

      ev = Event.order(:id).last
      expect(ev.kind).to eq('task_created')
      expect(ev.initiator).to eq(initiator)
      expect(ev.message['title']).to eq('Made')
    end
  end
end
