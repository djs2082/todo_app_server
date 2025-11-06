module UserInvitations
    class CreateService
        Result = Struct.new(:success?, :message, :invitation, :errors, :status, keyword_init: true)

        def initialize(account:, current_user:, params:)
            @account = account
            @current_user = current_user
            @params = params
        end

        def call
            role = Role.find_by(id: @params[:role_id])
            return Result.new(success?: false, message: I18n.t("errors.role_not_found"), invitation: nil, errors: nil, status: :not_found) unless role

            existing_user = User.find_by(email: @params[:email])
            if existing_user&.belongs_to_account?(@account)
                return Result.new(success?: false, message: I18n.t("errors.user_already_member"), invitation: nil, errors: nil, status: :unprocessable_entity)
            end

            existing_invitation = UserInvitation.active.find_by(email: @params[:email], account: @account)
            if existing_invitation
                return Result.new(success?: false, message: I18n.t("errors.invitation_already_exists"), invitation: nil, errors: nil, status: :unprocessable_entity)
            end

            invitation = UserInvitation.new(
                email: @params[:email],
                account: @account,
                role: role,
                inviter: @current_user
            )

            authorize_invitation(invitation)

            if invitation.save
                send_invitation_email(invitation)
                Result.new(success?: true, message: I18n.t("success.invitation_sent", default: "Invitation sent successfully"), invitation: invitation, errors: nil, status: :ok)
            else
                Result.new(success?: false, message: I18n.t("errors.invitation_send_failed", default: "Failed to send invitation"), invitation: nil, errors: invitation.errors.full_messages, status: :unprocessable_entity)
            end
        end

        private

        def authorize_invitation(invitation)
            Pundit.authorize(@current_user, invitation, :create?)
        end

        def send_invitation_email(invitation)
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
        rescue => e
            Rails.logger.error("Failed to send invitation email: #{e.message}")
            # Don't fail the invitation creation if email fails
        end

    end
end