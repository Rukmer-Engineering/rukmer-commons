import Config

if config_env() == :prod do
  config :marketplace_api, MarketplaceApiWeb.Endpoint,
    server: true,
    secret_key_base: System.get_env("SECRET_KEY_BASE") ||
      raise("Missing SECRET_KEY_BASE environment variable"),
    live_view: [
      signing_salt: System.get_env("SIGNING_SALT") ||
        raise("Missing SIGNING_SALT environment variable")
    ]

  config :marketplace_api, :cognito,
    user_pool_id: System.get_env("COGNITO_USER_POOL_ID") || "",
    client_id: System.get_env("COGNITO_CLIENT_ID") || "",
    region: System.get_env("AWS_REGION") || "us-east-1"

  config :marketplace_api, :aws,
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
    region: System.get_env("AWS_REGION") || "us-east-1"
end
