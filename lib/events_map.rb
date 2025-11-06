module EventsMap
end

_preload_models = [
    Event,
    User
]

class User < ApplicationRecord
    extend Events::Subscriber
    subscribe :user_signed_up, :send_activation_email
    subscribe :user_forgot_password, :send_forgot_password_email
    subscribe :user_password_updated, :send_password_updated_email
    subscribe :user_first_sign_in, :update_relevant_settings
    subscribe :user_invitation_created, :send_invitation_email
    subscribe :user_invitation_resend, :send_invitation_email

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

    def self.send_forgot_password_email(event, user)
        return unless user
        EmailService.send_email(
            to: user.email,
            template_name: 'forgot_password',
            context: {
                first_name: user.first_name,
                reset_url: reset_url_for(user)
            },
            async: false
        )
    end

    def self.send_password_updated_email(event, user)
        return unless user
        EmailService.send_email(
            to: user.email,
            template_name: 'password_reset_confirmation',
            context: {
                first_name: user.first_name
            },
            async: true
        )
    end

    def self.send_invitation_email(event, invitation)
        return unless invitation
        template_name = invitation.role.administrator? ? 'invite_admin' : 'invite_user'

        EmailService.send_email(
            to: invitation.email,
            template_name: template_name,
            context: {
                account_name: invitation.account.name,
                role_name: invitation.role.name.titleize,
                inviter_name: invitation.inviter ? "#{invitation.inviter.first_name} #{invitation.inviter.last_name}" : "An administrator",
                signup_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/signup?invitation_token=#{invitation.token}",
                expires_at: invitation.expires_at,
                expiry_days: UserInvitation::TOKEN_EXPIRY_DAYS
            },
            subject: EmailTemplate.find_by(name: template_name)&.subject&.gsub('{{account_name}}', invitation.account.name),
            async: true
        )
    end

    def self.update_relevant_settings(event, user)
        return unless user

        Rails.logger.info("User #{user.id} has signed in for the first time. Update settings as needed.")
        User::DEFAULT_SETTINGS_AND_PREFERENCES.each do |setting|
            user.settings.create!(key: setting[:key], value: setting[:value])
        end
    end
    
    private

    def self.activation_url(token)
        base = ENV.fetch('WEB_APP_BASE_URL', ENV.fetch('APP_BASE_URL', 'http://localhost:8000'))
        "#{base}/activate/#{token}"
    end

    def self.reset_url_for(user)
        base = ENV.fetch('APP_BASE_URL', 'http://localhost:8000')
        "#{base}/reset-password/#{user.reset_password_token}"
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