# config/initializers/resque.rb
require 'resque'

# Point Resque to Redis
Resque.redis = ENV.fetch("REDIS_URL") { "redis://redis:6379/0" }

# Optional: set namespace to avoid key conflicts
Resque.redis.namespace = "resque:karya_cache"

# Optional: configure logger
Resque.logger = Logger.new(STDOUT)
Resque.logger.level = Logger::INFO
