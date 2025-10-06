defmodule MarketplaceApiWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import Plug.Conn

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MarketplaceApiWeb.Layouts, :app}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  get "/health", do: send_resp(conn, 200, "ok")

  scope "/", MarketplaceApiWeb do
    pipe_through :browser
    live "/", AuthLive
  end
end
