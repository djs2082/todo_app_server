class UserRepresenter
  class << self
    def render(user)
      return nil unless user
      {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        mobile: user.mobile,
        settings: (user.respond_to?(:settings) ? SettingRepresenter.render_collection(user.settings) : [])
      }.compact
    end

    def render_collection(users)
      Array(users).map { |u| render(u) }
    end
  end
end
