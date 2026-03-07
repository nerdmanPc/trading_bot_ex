# filepath: /home/pedro/Documentos/Projetos/Elixir/trading_bot_ex/lib/kraken/market_listener.ex
defmodule Kraken.MarketListener do
  require Logger
  require DateTime
  use WebSockex

  def start_link(state) do
    state = state |> Map.put(:last_pong, System.system_time(:second))
    asset_symbol = System.get_env("ASSET_SYMBOL")
    quote_symbol = System.get_env("QUOTE_SYMBOL")
    state = Map.merge(state, %{
      pair: "#{asset_symbol}/#{quote_symbol}",
    })
    start_response = WebSockex.start_link("wss://ws.kraken.com/v2", __MODULE__, state, name: __MODULE__)
    case start_response do
      {:ok, pid} ->
        Logger.info("Kraken - Market listener started successfully.")
        :timer.send_interval(30_000, pid, :send_ping)
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Kraken - Failed to start market listener: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_info(:send_ping, state) do
    age = System.system_time(:second) - state.last_pong
    if age > 40 do
      Logger.warning("Kraken - Market listener ping timeout: #{age}s")
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

  def handle_connect(_conn, state) do
    subscribe_msg = %{
      "method" => "subscribe",
      "params" => %{
        "channel" => "trade",
        "symbol" => [
          state.pair
        ],
        "snapshot" => true,
      }
    }
    subscribe_msg = {:text, Jason.encode!(subscribe_msg)}
    client = self()
    subscribe = fn -> WebSockex.send_frame(client, subscribe_msg) end
    spawn_link(subscribe)
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded_msg} ->
        case decoded_msg do
          %{"channel" => "trade", "type" => "snapshot", "data" => trades} ->
            processed_trades = trades |> Enum.map(&process_trade(&1))
            GenServer.cast(TradingStrategy, {:snapshot, processed_trades})
            {:ok, state}
          %{"channel" => "trade", "type" => "update", "data" => trades} ->
            processed_trades = trades |> Enum.map(&process_trade(&1))
            GenServer.cast(TradingStrategy, {:update, processed_trades})
            {:ok, state}
          %{"channel" => "heartbeat"} ->
            {:ok, state}
          _ ->
            Logger.warning("Ignored message:\n#{inspect(decoded_msg)}")
            {:ok, state}
        end
      {:error, reason} ->
        Logger.error("Kraken - Failed to decode message:\n#{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_trade(trade) do
    {:ok, timestamp, _calendar} = DateTime.from_iso8601(trade["timestamp"])
    processed_trade = %{
      timestamp: timestamp, #TODO
      price: trade["price"],
      quantity: trade["qty"],
      trade_id: trade["trade_id"],
    }
    #GenServer.cast(Kraken.TradingStatus, {:update_kraken, processed_trade})
    processed_trade
  end

  def terminate(close_reason, state) do
    Logger.warning("Kraken - Market listener terminated with reason:\n#{inspect(close_reason)}")
    {:ok, state}
  end
end
