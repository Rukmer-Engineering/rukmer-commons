import Config

config :marketplace_api, MarketplaceApi.Repo,
  pool_size: 10,
  queue_target: 5000,
  queue_interval: 1000,
  timeout: 15_000,
  ownership_timeout: 30_000

# Use Jason for JSON
config :phoenix, :json_library, Jason

# Phoenix Endpoint configuration
# Dev: 127.0.0.1 (localhost only) | Prod: 0.0.0.0 (Docker needs this)
ip_binding = if Mix.env() == :prod, do: {0, 0, 0, 0}, else: {127, 0, 0, 1}

config :marketplace_api, MarketplaceApiWeb.Endpoint,
  http: [ip: ip_binding, port: 4000],
  # Hardcoded for dev (safe), production will override in runtime.exs if needed
  secret_key_base: "dev-secret-key-base-at-least-64-chars-long-for-local-dev-only-never-prod",
  live_view: [signing_salt: "dev-signing-salt-for-local-development"],
  session_signing_salt: "marketplace_api_session",
  pubsub_server: MarketplaceApi.PubSub,
  render_errors: [
    formats: [html: MarketplaceApiWeb.ErrorHTML, json: MarketplaceApiWeb.ErrorJSON],
    layout: false
  ]

# Development environment configuration
if Mix.env() == :dev do
  config :marketplace_api, MarketplaceApiWeb.Endpoint,
    # Enable code reloading in dev
    debug_errors: true,
    code_reloader: true,
    check_origin: false,
    # Watch files for changes and trigger live reload
    live_reload: [
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
        ~r"priv/gettext/.*(po)$",
        ~r"lib/marketplace_api_web/(controllers|live|components)/.*(ex|heex)$"
      ]
    ]
end

# AWS Cognito Configuration
# For dev: empty values (not needed locally)
# For prod: configure in runtime.exs with actual values from EC2 environment
config :marketplace_api, :cognito,
  user_pool_id: "",
  client_id: "",
  region: "us-east-1"

# AWS SDK configuration
# For dev: nil values (not needed locally)
# For prod: configure in runtime.exs or use IAM role on EC2
config :marketplace_api, :aws,
  access_key_id: nil,
  secret_access_key: nil,
  region: "us-east-1"
