# config/initializers/resque.rb
return if Rails.env.test?

require 'resque'

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
