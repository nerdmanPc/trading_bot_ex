defmodule Kraken.WsConnection do
  require Logger
  use WebSockex

  @api_base "https://api.kraken.com"
  @ws_token_path "/0/private/GetWebSocketsToken"

  def start_link(state) do
    state = state |> Map.put(:last_pong, System.system_time(:second))
    start_response = WebSockex.start_link("wss://ws.kraken.com/v2", __MODULE__, state)
    case start_response do
      {:ok, pid} ->
        Logger.info("Kraken - Data stream started successfully.")
        :timer.send_interval(30_000, pid, :send_ping)
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Kraken - Failed to start data stream: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_connect(_conn, state) do
    channel = Map.get(state, :channel)
    symbols = Map.get(state, :symbols, [])

    Logger.info("Kraken - Connected. Subscribing to #{channel} stream for #{inspect(symbols)}")

    # Send subscription immediately upon connection
    GenServer.cast(self(), {:subscribe, channel, symbols})

    {:ok, state}
  end

  def handle_info(:send_ping, state) do
    age = System.system_time(:second) - state.last_pong
    if age > 40 do
      Logger.warning("Kraken - Data stream ping timeout: #{age}s")
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

  def handle_cast({:subscribe, :trades, symbols}, state) when is_list(symbols) do

    subscription_msg = %{
      "method" => "subscribe",
      "params" => %{
        "channel" => "trade",
        "symbol" => symbols,
        "snapshot" => true
      }
    }
    subscription_msg = Jason.encode!(subscription_msg)

    {:reply, {:text, subscription_msg}, state}
  end

  def handle_cast({:subscribe, :orders, symbols}, state) when is_list(symbols) do

    subscription_msg = %{
      "method" => "subscribe",
      "params" => %{
        "channel" => "level3",
        "symbol" => symbols,
        "snapshot" => true,
        "token" => state.token,
        #"depth" => depth
      }
    }
    subscription_msg = Jason.encode!(subscription_msg)

    {:reply, {:text, subscription_msg}, state}
  end

  def handle_cast({:unsubscribe, :trades, symbols}, state) when is_list(symbols) do

    subscription_msg = %{
      "method" => "unsubscribe",
      "params" => %{
        "channel" => "trade",
        "symbol" => symbols,
      }
    }
    subscription_msg = Jason.encode!(subscription_msg)

    {:reply, {:text, subscription_msg}, state}
  end

  def handle_cast({:unsubscribe, :orders, symbols}, state) when is_list(symbols) do

    subscription_msg = %{
      "method" => "unsubscribe",
      "params" => %{
        "channel" => "level3",
        "symbol" => symbols,
        "token" => state.token,
        #"depth" => depth
      }
    }
    subscription_msg = Jason.encode!(subscription_msg)

    {:reply, {:text, subscription_msg}, state}
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded_msg} ->
        case decoded_msg do
          %{"channel" => "trade", "type" => "snapshot", "data" => trades} ->
            Logger.debug("Kraken - Received trade snapshot:\n#{inspect(trades)}")
            GenServer.cast(state.destination, {:trades_snapshot, trades})
            #processed_trades = trades |> Enum.map(&process_trade(&1))
            #broadcast(state.registry, {:trades, :snapshot, state.pair}, processed_trades)
            {:ok, state}
          %{"channel" => "trade", "type" => "update", "data" => trades} ->
            Logger.debug("Kraken - Received trade update:\n#{inspect(trades)}")
            GenServer.cast(state.destination, {:trades_update, trades})
            #processed_trades = trades |> Enum.map(&process_trade(&1))
            #broadcast(state.registry, {:trades, :update, state.pair}, processed_trades)
            {:ok, state}
          %{"channel" => "level3", "type" => "snapshot", "data" => order_book} ->
            Logger.debug("Kraken - Received order book snapshot:\n#{inspect(order_book)}")
            GenServer.cast(state.destination, {:order_book_snapshot, order_book})
            #broadcast(state.registry, {:orders, :snapshot, state.pair}, order_book)
            {:ok, state}
          %{"channel" => "level3", "type" => "update", "data" => order_book} ->
            Logger.debug("Kraken - Received order book update:\n#{inspect(order_book)}")
            GenServer.cast(state.destination, {:order_book_update, order_book})
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

  def terminate(close_reason, state) do
    Logger.warning("Kraken - Market listener terminated with reason:\n#{inspect(close_reason)}")
    {:ok, state}
  end
end
