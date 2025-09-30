defmodule MarketplaceApi.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Database connection
      MarketplaceApi.Repo,
      {
        Plug.Cowboy,
        scheme: :http,
        plug: HelloWorld,
        options: [port: String.to_integer(System.get_env("PORT") || "4000")]
      }
    ]
    opts = [strategy: :one_for_one, name: MarketplaceApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
