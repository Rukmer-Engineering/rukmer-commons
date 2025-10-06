defmodule MarketplaceApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :marketplace_api,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
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
      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},

      # Phoenix LiveView (includes Jason automatically)
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 0.20.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:plug_cowboy, "~> 2.7"},

      # UI Components
      {:salad_ui, "~> 0.9.0"},
      {:tails, "~> 0.1.5"},

      # AWS Cognito Integration
      {:aws, "~> 1.0.9"},

      # JSON library (required by Phoenix and AWS SDK)
      {:jason, "~> 1.4"}
    ]
  end

  defp releases do
    [
      marketplace_api: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end
end
