module UserInvitations
    class CreateService
        def initialize(account:, current_user:, params:)
            @account = account
            @current_user = current_user
            @params = params
        end

        def call
            Result = Struct.new(:success?, :message, :invitation, :errors, :status, keyword_init: true)
            role = Role.find_by(id: @params[:role_id])
            return Result.new(false, I18n.t("errors.role_not_found"), nil, nil, :not_found) unless role

            existing_user = User.find_by(email: @params[:email])
            if existing_user&.belongs_to_account?(@account)
                return Result.new(false, I18n.t("errors.user_already_member"), nil, nil, :unprocessable_entity)
            end

            existing_invitation = UserInvitation.active.find_by(email: @params[:email], account: @account)
            if existing_invitation
                return Result.new(false, I18n.t("errors.invitation_already_exists"), nil, nil, :unprocessable_entity)
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
                Result.new(true, I18n.t("success.invitation_sent"), invitation, nil, :ok)
            else
                Result.new(false, I18n.t("errors.invitation_send_failed"), nil, invitation.errors.full_messages, :unprocessable_entity)
            end
        end

        private
    
        def authorize_invitation(invitation)
            Pundit.authorize(@current_user, invitation, :create?)
        end

    end
end