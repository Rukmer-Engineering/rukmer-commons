defmodule MarketplaceApiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :marketplace_api

  @session_options [
    store: :cookie,
    key: "_marketplace_api_key",
    signing_salt: Application.compile_env!(:marketplace_api, [MarketplaceApiWeb.Endpoint, :session_signing_salt])
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  # Serve static files and handle errors
  plug Plug.Static,
    at: "/",
    from: :marketplace_api,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MarketplaceApiWeb.Router
end
