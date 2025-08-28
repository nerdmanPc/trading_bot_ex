defmodule Mexc.AccountListener do
  require Logger
  use WebSockex

  def start_link(state) do
    state = state |> Map.put(:last_pong, System.system_time(:second))
    api_key = System.get_env("API_KEY")
    api_secret = System.get_env("API_SECRET")
    listen_key = Mexc.RestApi.get_listen_key!(api_key, api_secret)
    response = WebSockex.start_link("wss://wbs-api.mexc.com/ws?listenKey=#{listen_key}", __MODULE__, state, name: __MODULE__)
    case response do
      {:ok, pid} ->
        Logger.info("MEXC - Account listener started successfully.")
        :timer.send_interval(30_000, pid, :send_ping)
        {:ok, pid}
      {:error, reason} ->
        Logger.error("MEXC - Failed to start account listener: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_info(:send_ping, state) do
    age = System.system_time(:second) - state.last_pong
    if age > 40 do
      Logger.warning("MEXC - Account listener ping timeout: #{age}s")
      {:close, state}
    else
      {:reply, :ping, state}
    end
  end

  def handle_ping(ping_frame, state) do
    {:reply, ping_frame, state}
  end

  def handle_pong(_pong_frame, state) do
    {:ok, state |> Map.put(:last_pong, System.system_time(:second))}
  end

  def handle_connect(_conn, state) do
    subscribe_msg = %{
      "method" => "SUBSCRIPTION",
      "params" => ["spot@private.account.v3.api.pb"],
    }
    subscribe_msg = {:text, Jason.encode!(subscribe_msg)}
    client = self()
    subscribe = fn -> WebSockex.send_frame(client, subscribe_msg) end
    spawn_link(subscribe)
    {:ok, state}
  end

  def handle_frame({:binary, msg}, state) do #TODO
    case Protox.decode(msg, PrivateAccountV3Api) do
      {:ok, decoded_msg} ->
        payload = decoded_msg.privateAccount
        new_balance = %{
          symbol: payload.coinName,
          free: Decimal.new(payload.balanceAmount),
          locked: Decimal.new(payload.frozenAmount),
        }
        GenServer.cast(Mexc.TradingStatus, {:update_balance, new_balance})
        {:ok, state}
      {:error, reason} ->
        Logger.error("MEXC - Failed to decode message:\n#{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_frame({:text, msg}, state) do
    Logger.info("MEXC - Received text frame:\n#{msg}")
    {:ok, state}
  end

  def terminate(close_reason, state) do
    Logger.warning("MEXC - Account listener terminated with reason:\n#{inspect(close_reason)}")
    {:ok, state}
  end
end
