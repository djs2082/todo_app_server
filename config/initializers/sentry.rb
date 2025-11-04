Sentry.init do |config|
  # DSN from environment; if blank, Sentry remains disabled.
  config.dsn = ENV["SENTRY_DSN"]

  # Enable Sentry only in staging and production
  config.enabled_environments = %w[staging production]

  # Attach breadcrumbs from Rails and HTTP
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Capture personally identifiable information when appropriate
  config.send_default_pii = false # Changed to false for GDPR compliance

  # Sanitize sensitive fields
  config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)

  # Set environment and release (optional: read from ENV / git SHA)
  config.environment = ENV.fetch("SENTRY_ENV", Rails.env)
  config.release = ENV["SENTRY_RELEASE"] || ENV["APP_VERSION"] || `git rev-parse --short HEAD`.strip

  # Performance monitoring (adjust rates to your needs)
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", "0.1").to_f

  # Don't send certain exception types (reduce noise)
  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound',
    'ActionController::InvalidAuthenticityToken',
    'ActionController::UnknownFormat',
    'AbstractController::ActionNotFound',
    'Pundit::NotAuthorizedError'
  ]

  # Configure tags for better filtering
  config.tags = {
    environment: config.environment,
    server_name: ENV['HOSTNAME'] || 'unknown'
  }

  # Dynamic sampling based on endpoint
  config.traces_sampler = lambda do |sampling_context|
    # Health checks - don't sample
    if sampling_context.dig(:env, 'REQUEST_PATH')&.match?(/\/health|\/ready|\/live/)
      0.0
    # API endpoints - sample based on environment
    elsif sampling_context.dig(:env, 'REQUEST_PATH')&.start_with?('/api/')
      Rails.env.production? ? 0.05 : 0.5
    # Background jobs - sample more
    elsif sampling_context[:transaction_context][:op] == 'queue.process'
      0.5
    else
      0.1
    end
  end

  # Custom error processor
  config.before_send = lambda do |event, hint|
    # Filter out bot/crawler errors
    if event.request&.headers&.dig('User-Agent')&.match?(/bot|crawler|spider/i)
      nil # Don't send
    else
      event
    end
  end

  # Integrations
  config.rails.report_rescued_exceptions = true # also capture exceptions rescued by Rails

  # Resque integration (captures job exceptions)
  if defined?(Resque)
    config.background_worker_threads = 5
    config.breadcrumbs_logger << :resque
  end

  # Sidekiq integration (for future migration)
  if defined?(Sidekiq)
    config.breadcrumbs_logger << :sidekiq
  end

  # Logging
  config.logger = Rails.logger
  config.debug = false
end