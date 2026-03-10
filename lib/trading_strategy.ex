defmodule TradingStrategy do
  @moduledoc """
  Market Making strategy that consolidates trades into candles and updates orders based on EMA indicator.
  """
  require Logger
  alias DateTime, as: DT
  require Calendar
  require Duration
  use GenServer

  defstruct [
    :pair,
    :ema_window,
    :spread,
    :ema_value,
    :candles,
    :latency_ms,
    :tick_timer,
  ]

  @type t :: %__MODULE__{
    pair: String.t(),
    ema_window: pos_integer(),
    spread: float(),
    ema_value: float() | nil,
    candles: list(),
    latency_ms: integer() | nil,
    tick_timer: reference() | nil,
  }

  @spec start_link(false | nil | map()) :: {:error, any()} | {:ok, pid()}
  def start_link(args) do
    response = GenServer.start_link(__MODULE__, args, name: __MODULE__)
    case response do
      {:ok, _pid} ->
        Logger.info("Trading strategy started successfully")
        response
      {:error, reason} ->
        Logger.error("Trading strategy failed to start: #{inspect(reason)}")
        response
    end
  end

  @spec init(any()) :: {:ok, TradingStrategy.t()}
  def init(_args) do
    #schedule_tick(nil)
    {:ok, new()}
  end

  def handle_cast({:snapshot, trade_list}, state) do
    state = update_strategy(state, trade_list, [])
    new_timer = schedule_tick(state.tick_timer, state.latency_ms)
    {:noreply, %__MODULE__{state | tick_timer: new_timer}}
  end

  def handle_cast({:update, trade_list}, state) do
    state = update_strategy(state, trade_list, state.candles)
    new_timer = schedule_tick(state.tick_timer, state.latency_ms)
    {:noreply, %__MODULE__{state | tick_timer: new_timer}}
  end

  def handle_info(:tick, state) do
    state = update_strategy(state, [], state.candles)
    Logger.debug("Recived tick!")
    new_timer = schedule_tick(state.tick_timer, state.latency_ms)
    {:noreply, %__MODULE__{state | tick_timer: new_timer}}
  end

  def terminate(close_reason, state) do
    Logger.warning("Trading strategy terminated with reason: #{inspect(close_reason)}")
    {:ok, state}
  end

  defp schedule_tick(current_timer, latency_ms) do
    if current_timer do
      Process.cancel_timer(current_timer)
    end
    current_time = DT.utc_now(:millisecond)
    next_tick =
      DT.truncate(current_time, :second)
      |> DT.add(1, :second)
      |> DT.add(latency_ms, :millisecond)
    next_tick_delta = DT.diff(next_tick, current_time, :millisecond)
    Process.send_after(self(), :tick, next_tick_delta)
  end

  defp new() do
    %__MODULE__{
      pair: System.get_env("ASSET_SYMBOL") <> "/" <> System.get_env("QUOTE_SYMBOL"),
      ema_window: System.get_env("EMA_WINDOW") |> String.to_integer(),
      spread: System.get_env("SPREAD") |> String.to_float(),
      ema_value: nil,
      candles: [],
      latency_ms: nil,
      tick_timer: nil,
    }
  end

  defp update_strategy(strategy, trade_list, starting_candles) do
    new_latency = update_latency(strategy.latency_ms, trade_list)
    #Logger.info("Latency: #{inspect(new_latency)}")
    new_candles = update_candles(starting_candles, trade_list, strategy.ema_window, new_latency)
    #Logger.info("Candles: #{inspect(new_candles)}")
    new_ema = calculate_ema(new_candles, strategy.ema_window)
    new_strategy = %__MODULE__{strategy | candles: new_candles, ema_value: new_ema, latency_ms: new_latency}
    update_orders(new_strategy)
  end

  defp update_latency(current_latency, []) do current_latency end
  defp update_latency(current_latency, trade_list) do
    server_time = trade_list |> Stream.map(&(&1.timestamp)) |> Enum.max(DT)
    latency_sample = DT.utc_now(:millisecond) |> DT.diff(server_time, :millisecond)
    if current_latency do
      (current_latency + latency_sample) |> div(2)
    else
      latency_sample
    end
  end

  defp update_candles(candles, trade_list, ema_window, latency_ms) do
    estimated_timestamp = DT.utc_now(:millisecond) |> DT.add(-latency_ms, :millisecond)
    ffill_timestamp = trade_list |> Enum.map(&(&1.timestamp)) |> Enum.min(DT, fn -> estimated_timestamp end)
    new_candles = fill_empty_candles(candles, ffill_timestamp, ema_window)
    consolidate_trades(new_candles, trade_list, ema_window)
  end

  defp fill_empty_candles([], _timestamp, _window) do [] end
  defp fill_empty_candles(candles, timestamp, window) do
    last_candle = List.last(candles)
    last_timestamp = DT.to_unix(last_candle.timestamp)
    target_timestamp = DT.to_unix(timestamp)

    if target_timestamp > last_timestamp do
      timestamp_range = (last_timestamp + 1)..target_timestamp
      add_empty_candle = fn unix_time, acc ->
        {:ok, timestamp} = DT.from_unix(unix_time)
        acc ++ [%{timestamp: timestamp, price: last_candle.price}]
      end
      new_candles = Enum.reduce(timestamp_range, candles, add_empty_candle)
      Enum.take(new_candles, -window)
    else
      candles
    end
  end

  defp consolidate_trades(candles, [], _window) do candles end
  defp consolidate_trades(candles, trade_list, window) do
    [ first_trade | remaining_trades ] = trade_list
    new_candles = consolidate_trade(candles, first_trade, window)
    consolidate_trades(new_candles, remaining_trades, window)
  end

  defp consolidate_trade([], trade, _window) do [trade] end
  defp consolidate_trade(candles, trade, window) do
    trade = %{timestamp: trade.timestamp, price: trade.price}
    compare_trade_timestamps = fn trade_a, trade_b ->
      compare_result = DT.compare(trade_a.timestamp, trade_b.timestamp)
      compare_result == :eq or compare_result == :gt
    end
    last_candle = Enum.max(candles, compare_trade_timestamps)#List.last(candles)
    cond do
      DT.compare(trade.timestamp, last_candle.timestamp) == :lt ->
        Logger.warning("Ignored trade: #{inspect(trade)}")
        candles
      same_candle_period?(last_candle.timestamp, trade.timestamp) ->
        candles |> List.replace_at(-1, trade)
      true ->
        candles |> List.insert_at(length(candles), trade) |> Enum.take(-window)
    end
  end

  defp same_candle_period?(timestamp_a, timestamp_b) do
    DT.to_unix(timestamp_a) == DT.to_unix(timestamp_b)
  end

  defp calculate_ema(candles, window) when length(candles) < window, do: nil
  defp calculate_ema(candles, window) do
    prices = candles |> Enum.map(& :math.log(&1.price))
    sma = Enum.sum(prices) / window

    multiplier = 2.0 / (window + 1)
    get_ema_term = fn price, last_ema ->
      price * multiplier + last_ema * (1 - multiplier)
    end
    Enum.reduce(prices, sma, get_ema_term) |> :math.exp()
  end

  defp update_orders(strategy) do
    if strategy.ema_value do
      long_price = strategy.ema_value / (1 + strategy.spread)
      short_price = strategy.ema_value * (1 + strategy.spread)
      mid_price = strategy.ema_value
      #Logger.info("Order sent at prices: #{long_price} - #{mid_price} - #{short_price}")
    end
    strategy
  end
end
