# Prometheus Metrics Exporter
# Exposes /metrics endpoint for Prometheus scraping

if defined?(Prometheus) && (Rails.env.staging? || Rails.env.production?)
  require 'prometheus_exporter/middleware'
  require 'prometheus_exporter/instrumentation'

  # Start the prometheus exporter process
  unless ENV['PROMETHEUS_EXPORTER_ENABLED'] == 'false'
    # Default metrics port
    PrometheusExporter::Metric::Base.default_prefix = 'todoapp'

    # Custom metrics collector
    PrometheusExporter::Server::Collector.register_metric(
      PrometheusExporter::Metric::Gauge.new('todoapp_info', 'Application info')
    )

    # Application info metric
    PrometheusExporter::Client.default.send_json(
      type: 'todoapp_info',
      value: 1,
      labels: {
        version: ENV['APP_VERSION'] || 'unknown',
        environment: Rails.env,
        ruby_version: RUBY_VERSION
      }
    )
  end
end

# Note: To use this, add these gems to Gemfile:
# gem 'prometheus_exporter'
# gem 'prometheus-client'
