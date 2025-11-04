Sentry.init do |config|
  # DSN from environment; if blank, Sentry remains disabled.
  config.dsn = ENV["SENTRY_DSN"]

  # Attach breadcrumbs from Rails and HTTP
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Capture personally identifiable information when appropriate
  config.send_default_pii = true

  # Set environment and release (optional: read from ENV / git SHA)
  config.environment = ENV.fetch("SENTRY_ENV", Rails.env)
  config.release = ENV["SENTRY_RELEASE"] if ENV["SENTRY_RELEASE"].present?

  # Performance monitoring (adjust rates to your needs)
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.0").to_f
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", "0.0").to_f

  # Integrations
  config.rails.report_rescued_exceptions = true # also capture exceptions rescued by Rails

  # Resque integration (captures job exceptions)
  if defined?(Resque)
    config.background_worker_threads = 5
  end
end