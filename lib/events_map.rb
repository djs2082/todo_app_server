module EventsMap
end

_preload_models = [
    Event,
    User
]

class User < ApplicationRecord
    extend Events::Subscriber
    subscribe :user_signed_up, :send_activation_email

    def self.send_activation_email(event, user)
         return unless user
        EmailService.send_email(
            to: user.email,
            template_name: 'account_activation',
            context: {
                first_name: user.first_name,
                activation_url: activation_url(user.activation_token)
            },
            async: false
        )
    end
    
    private

    def self.activation_url(token)
        base = ENV.fetch('WEB_APP_BASE_URL') { 'http://localhost:8000' }
        "#{base}/activate/#{token}"
    end
end

class Event < ApplicationRecord
    extend Events::Subscriber

    subscribe EVENTS_LIST, :create_event

    def self.create_event(event, object, initiator, more={})
        message = object.default_event_message.merge(more).stringify_keys!
        initiator_args = (initiator.is_a?(Hash) && initiator[:name] == "System") ? {initiator_type: "System", id: nil} : {initiator: initiator}
        Event.create!({subject: object, kind: event, message: message, created_at: DateTime.now.utc}.merge(initiator_args))
    end

    def self.default_event_message(object)
      {title: object.name, description: object.description}
    end
end