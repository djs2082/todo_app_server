Rails.application.config.to_prepare do
  # Eager load all app code (models, lib if in autoload_paths)
  Rails.autoloaders.main.eager_load
end