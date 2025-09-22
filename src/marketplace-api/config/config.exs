import Config

config :marketplace_api, MarketplaceApi.Repo,
  pool_size: 10,
  queue_target: 5000,
  queue_interval: 1000,
  timeout: 15_000,
  ownership_timeout: 30_000

# Use Jason for JSON
config :phoenix, :json_library, Jason
