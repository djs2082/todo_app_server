class SettingRepresenter
  class << self
    def render(setting)
      return nil unless setting
      {
        id: setting.id,
        key: setting.key,
        value: setting.value,
      }.compact
    end

    def render_collection(settings)
      Array(settings).map { |s| render(s) }
    end
  end
end
