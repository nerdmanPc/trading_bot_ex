defmodule Mexc.MarketListener do
  require Logger
  use WebSockex

  def start_link(state) do
    state = state |> Map.put(:last_pong, System.system_time(:second))
    asset_symbol = System.get_env("ASSET_SYMBOL")
    quote_symbol = System.get_env("QUOTE_SYMBOL")
    state = Map.merge(state, %{
      symbol: asset_symbol <> quote_symbol,
      period: "Min1",
    })
    response = WebSockex.start_link("wss://wbs-api.mexc.com/ws", __MODULE__, state, name: __MODULE__)
    case response do
      {:ok, pid} ->
        Logger.info("MEXC - Market listener started successfully.")
        :timer.send_interval(30_000, pid, :send_ping)
        {:ok, pid}
      {:error, reason} ->
        Logger.error("MEXC - Failed to start market listener: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_info(:send_ping, state) do
    age = System.system_time(:second) - state.last_pong
    if age > 40 do
      Logger.warning("MEXC - Market listener ping timeout: #{age}s")
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
      "method" => "SUBSCRIPTION",
      "params" => ["spot@public.kline.v3.api.pb@#{state.symbol}@#{state.period}"],
    }
    subscribe_msg = {:text, Jason.encode!(subscribe_msg)}
    client = self()
    subscribe = fn -> WebSockex.send_frame(client, subscribe_msg) end
    spawn_link(subscribe)
    {:ok, state}
  end

  def handle_frame({:binary, msg}, state) do
    case Protox.decode(msg, PublicSpotKlineV3Api) do
      {:ok, decoded_msg} ->
        payload = decoded_msg.publicSpotKline
        new_candle = %{
          time: decoded_msg.createTime |> DateTime.from_unix!(:millisecond),
          price: payload.closingPrice |> Decimal.new(),
        }
        GenServer.cast(Mexc.TradingStatus, {:update_mexc, new_candle})
        {:ok, state}
      {:error, reason} ->
        Logger.error("MEXC - Failed to decode message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_frame({:text, msg}, state) do
    Logger.info("MEXC - Recieved text frame:\n#{msg}")
    {:ok, state}
  end

  def terminate(close_reason, state) do
    Logger.warning("MEXC - Market listener terminated with reason:\n#{inspect(close_reason)}")
    {:ok, state}
  end
end
