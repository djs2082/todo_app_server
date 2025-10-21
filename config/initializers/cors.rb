# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # ALLOWED_HOSTS can be a comma-separated list, e.g. "api.karya-app.com,localhost"
    env_allowed = ENV.fetch("ALLOWED_HOSTS", "localhost").split(",").map(&:strip)
    # Ensure localhost:8080 is always allowed for local frontend development
    allowed = (env_allowed + ["http://localhost:8000", "http://localhost"]).uniq
    origins allowed

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
