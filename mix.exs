defmodule TradingBotEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :crypto_pipeline,
      version: "1.0.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        trading_bot_ex: [
          include_executables_for: [:unix],
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {CryptoPipeline, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:decimal, "~> 2.4"},
      {:websockex, "~> 0.4"},
      {:mint, "~> 1.9"},
      {:dotenv, "~> 3.1"},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end
