defmodule Farmbot.Ext.MixProject do
  use Mix.Project

  def project do
    [
      app: :farmbot_ext,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Farmbot.Ext, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:farmbot_core, path: "../farmbot_core", env: Mix.env()},
      {:httpoison, "~> 1.2"},
      {:jason, "~> 1.0"},
      {:uuid, "~> 1.1"},
      {:amqp, "~> 1.0"},
      {:rsa, "~> 0.0.1"},
      {:fs, "~> 3.4"},
    ]
  end
end
