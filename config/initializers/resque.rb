# config/initializers/resque.rb
return if Rails.env.test?

require 'resque'
require 'sentry/resque'

Resque.redis = ENV.fetch("REDIS_URL") { "redis://redis:6379/0" }

Resque.redis.namespace = "resque:karya_cache"

Resque.logger = Logger.new(STDOUT)
Resque.logger.level = Logger::INFO

schedule_file = Rails.root.join('config', 'resque_schedule.yml')
if File.exist?(schedule_file) && Resque.respond_to?(:schedule=)
	yaml = YAML.load_file(schedule_file)
	schedule_hash = yaml.is_a?(Hash) ? (yaml['schedule'] || yaml[:schedule] || {}) : {}
	Resque.schedule = schedule_hash
end

	# Send job failures to Sentry (without requiring the optional Multiple backend)
	if defined?(Sentry::Resque::Failure)
		Resque::Failure.backend = Sentry::Resque::Failure
	end
