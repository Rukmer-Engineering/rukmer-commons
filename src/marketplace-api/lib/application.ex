defmodule MarketplaceApi.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: MarketplaceApi.PubSub},
      MarketplaceApiWeb.Endpoint
    ]
    opts = [strategy: :one_for_one, name: MarketplaceApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
