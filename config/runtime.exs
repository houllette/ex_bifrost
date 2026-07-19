import Config

# Runtime configuration for production and other environments.
# This file is evaluated at runtime, allowing for environment variable configuration.

config :ex_bifrost,
  base_url: System.get_env("API_BASE_URL", "http://localhost:8080")

# Connection pool configuration — adjust based on your expected load:
# config :ex_bifrost,
#   pool_size: String.to_integer(System.get_env("HTTP_POOL_SIZE", "25")),
#   pool_count: String.to_integer(System.get_env("HTTP_POOL_COUNT", "1")),
#   connect_timeout: String.to_integer(System.get_env("HTTP_CONNECT_TIMEOUT", "5000"))

# Logging Configuration
if config_env() == :prod do
  config :logger,
    level: :info
end

if config_env() == :dev do
  config :logger,
    level: :debug
end
