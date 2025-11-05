class AccountRepresenter
  class << self
    # Render a single account
    # detailed: when true, include account_users with user and role details (for show)
    def render(account, detailed: false)
      return nil unless account

      base = {
        id: account.id,
        name: account.name,
        slug: account.slug,
        active: account.respond_to?(:active) ? account.active : nil,
        createdAt: account.created_at,
        updatedAt: (account.updated_at if detailed),
        userCount: (account.user_count if account.respond_to?(:user_count))
      }.compact

      if detailed
        base[:accountUsers] = account.account_users.as_json(
          only: [:id, :active, :created_at],
          include: {
            user: { only: [:id, :first_name, :last_name, :email] },
            role: { only: [:id, :name, :description] }
          }
        )
      else
        base[:users] = account.users.as_json(
          only: [:id, :first_name, :last_name, :email],
          include: {
            account_users: {
              only: [:role_id],
              include: {
                role: { only: [:name] }
              }
            }
          }
        )
      end

      base
    end

    # Render a collection of accounts for listing
    def render_collection(accounts)
      Array(accounts).map { |a| render(a, detailed: false) }
    end
  end
end
