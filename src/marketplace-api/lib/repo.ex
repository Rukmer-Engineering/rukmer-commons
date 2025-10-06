defmodule MarketplaceApi.Repo do
  use Ecto.Repo,
    otp_app: :marketplace_api,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Dynamically loads the repository configuration from environment variables.
  """
  def init(_, opts) do
    config = [
      hostname: System.get_env("DB_HOST") || "localhost",
      port: String.to_integer(System.get_env("DB_PORT") || "5432"),
      database: System.get_env("DB_NAME") || "rukmer_marketplace",
      username: System.get_env("DB_USER") || "rukmer_admin",
      password: System.get_env("DB_PASSWORD") || ""
    ]

    {:ok, Keyword.merge(opts, config)}
  end
end
