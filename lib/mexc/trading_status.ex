defmodule Mexc.TradingStatus do
  use GenServer
  require Logger

  def start_link(args) do
    asset_symbol = System.get_env("ASSET_SYMBOL")
    quote_symbol = System.get_env("QUOTE_SYMBOL")

    api_key = System.get_env("API_KEY")
    api_secret = System.get_env("API_SECRET")

    balances = Mexc.RestApi.get_balances!(api_key, api_secret)
    asset_balance = balances |> Enum.find(%{"free" => "0.0", "locked" => "0.0"}, fn x -> x["asset"] == asset_symbol end) |> Map.get("free") |> Decimal.new()
    quote_balance = balances |> Enum.find(%{"free" => "0.0", "locked" => "0.0"}, fn x -> x["asset"] == quote_symbol end) |> Map.get("free") |> Decimal.new()

    args = Map.merge(%{
      asset_symbol: asset_symbol,
      quote_symbol: quote_symbol,
      asset_balance: asset_balance,
      quote_balance: quote_balance
    }, args || %{})

    response = GenServer.start_link(__MODULE__, args, name: __MODULE__)
    case response do
      {:ok, _pid} ->
        Logger.info("Trading status started successfully")
        response
      {:error, reason} ->
        Logger.error("Trading status failed to start: #{inspect(reason)}")
        response
    end
  end

  def init(init_arg) do
    { :ok, initial_state(init_arg) }
  end

  def handle_cast({:update_binance, candle}, state) do
    new_state = update_binance_candle(candle, state)
    {:noreply, new_state}
  end

  def handle_cast({:update_mexc, candle}, state) do
    new_state = update_mexc_candle(candle, state)
    {:noreply, new_state}
  end

  def handle_cast({:update_balance, balance}, state) do
    new_state = update_balance(balance, state)
    {:noreply, new_state}
  end

  def terminate(close_reason, state) do
    Logger.warning("Trading status terminated with reason: #{inspect(close_reason)}")
    {:ok, state}
  end

  def initial_state(init_arg) do
    %{
      symbols: %{
        :asset => init_arg.asset_symbol,
        :quote => init_arg.quote_symbol
      },
      candles: %{
        binance: nil,
        mexc: nil
      },
      balances: %{
        :asset => %{
          free: init_arg.asset_balance,
          locked: Decimal.new("0.0"),
        },
        :quote => %{
          free: init_arg.quote_balance,
          locked: Decimal.new("0.0"),
        }
      }
    }
  end

  def update_binance_candle(candle, state) do
    new_state = put_in(state.candles.binance, candle)
    notify_strategies(new_state, :new_candle)
    new_state
  end

  def update_mexc_candle(candle, state) do
    new_state = put_in(state.candles.mexc, candle)
    notify_strategies(new_state, :new_candle)
    new_state
  end

  def update_balance(balance, state) do
    asset_symbol = state.symbols.asset
    quote_symbol = state.symbols.quote
    new_balance = %{free: balance.free, locked: balance.locked}
    case balance do
      %{symbol: ^asset_symbol} ->
        new_state = put_in(state.balances.asset, new_balance)
        Logger.info("Updated asset balances:\n#{inspect(new_balance)}")
        notify_strategies(new_state, :new_balance)
        new_state
      %{symbol: ^quote_symbol} ->
        new_state = put_in(state.balances.quote, new_balance)
        Logger.info("Updated quote balances:\n#{inspect(new_balance)}")
        notify_strategies(new_state, :new_balance)
        new_state
      _else ->
        state
    end
  end

  defp notify_strategies(new_state, tag) do
    status = %{
      candles: new_state.candles,
      balances: new_state.balances
    }
    #Logger.info("Notifying strategies with status:\n#{inspect(status)}")
    GenServer.cast(Mexc.TradingStrategy, {tag, status})
  end
end
