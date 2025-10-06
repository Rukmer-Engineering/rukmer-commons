import Config

if config_env() == :prod do
  config :marketplace_api, MarketplaceApiWeb.Endpoint, server: true
end
