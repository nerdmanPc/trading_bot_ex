defmodule TradingBotEx do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    start_app()
  end

  defp start_app() do
    children = [
      { Binance.MarketListener, %{} },
      { Mexc.MarketListener, %{} },
      { Mexc.AccountListener, %{} },
      { Mexc.TradingStatus, %{} },
      { Mexc.TradingStrategy, %{} }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
