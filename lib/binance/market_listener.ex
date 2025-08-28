defmodule Binance.MarketListener do
  require Logger
  use WebSockex

  def start_link(state) do
    state = state |> Map.put(:last_pong, System.system_time(:second))
    asset_symbol = System.get_env("ASSET_SYMBOL")
    quote_symbol = System.get_env("QUOTE_SYMBOL")
    url = "wss://stream.binance.com/ws/#{String.downcase(asset_symbol <> quote_symbol)}@kline_1m"
    response = WebSockex.start_link(url, __MODULE__, state, name: __MODULE__)
    case response do
      {:ok, pid} ->
        Logger.info("Binance - Market listener started successfully.")
        :timer.send_interval(30_000, pid, :send_ping)
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Binance - Failed to start market listener:\nReason: #{inspect(reason)}\nURL: #{url}")
        {:error, reason}
    end
  end

  def handle_info(:send_ping, state) do
    age = System.system_time(:second) - state.last_pong
    if age > 40 do
      Logger.warning("Binance - Market listener ping timeout: #{age}s")
      {:close, state}
    else
      {:reply, :ping, state}
    end
  end

  def handle_ping(_ping_frame, state) do
    {:reply, :pong, state}
  end

  def handle_pong(_pong_frame, state) do
    {:ok, state |> Map.put(:last_pong, System.system_time(:second))}
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded_msg} ->
        candle = decoded_msg |> Map.get("k", %{})
        new_candle = %{
          closed: candle |> Map.get("x", false),
          time: decoded_msg |> Map.get("E", nil) |> DateTime.from_unix!(:millisecond),
          price: candle |> Map.get("c", nil) |> Decimal.new()
        }
        GenServer.cast(Mexc.TradingStatus, {:update_binance, new_candle})
        {:ok, state}
      {:error, reason} ->
        Logger.error("Binance - Failed to decode message: #{reason}")
        {:error, reason}
    end
  end

  def terminate(close_reason, state) do
    Logger.warning("Binance - Market listener terminated with reason:\n#{inspect(close_reason)}")
    {:ok, state}
  end
end
