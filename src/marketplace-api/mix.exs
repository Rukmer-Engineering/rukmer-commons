defmodule MarketplaceApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :marketplace_api,
      version: "0.1.0",
      elixir: "1.18.4-otp-27",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MarketplaceApi.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.5"}
    ]
  end
end
