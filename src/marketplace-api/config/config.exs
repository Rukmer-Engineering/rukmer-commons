import Config

config :marketplace_api, MarketplaceApi.Repo,
  pool_size: 10,
  queue_target: 5000,
  queue_interval: 1000,
  timeout: 15_000,
  ownership_timeout: 30_000

# Use Jason for JSON
config :phoenix, :json_library, Jason

# LiveView signing salt - uses env var in production, safe default for dev
config :phoenix_live_view,
  signing_salt: System.get_env("SIGNING_SALT") || "dev-salt-not-for-production"

# Phoenix Endpoint configuration
config :marketplace_api, MarketplaceApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  # IMPORTANT: Set SECRET_KEY_BASE environment variable in production!
  # Generate with: mix phx.gen.secret
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  live_view: [signing_salt: System.get_env("SIGNING_SALT")],
  pubsub_server: MarketplaceApi.PubSub,
  render_errors: [
    formats: [html: MarketplaceApiWeb.ErrorHTML, json: MarketplaceApiWeb.ErrorJSON],
    layout: false
  ]

# AWS Cognito Configuration
# IMPORTANT: Run `terraform output cognito_setup_instructions` to get these values
config :marketplace_api, :cognito,
  user_pool_id: System.get_env("COGNITO_USER_POOL_ID") || "",
  client_id: System.get_env("COGNITO_CLIENT_ID") || "",
  region: System.get_env("AWS_REGION") || "us-east-1"

# AWS SDK configuration - uses IAM role on EC2
config :marketplace_api, :aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION")
