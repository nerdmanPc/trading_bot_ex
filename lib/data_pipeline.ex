defmodule DataPipeline do
  require Logger
  use GenServer

  def start_link(initial_state \\ %{}) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(init_arg) do
    #Logger.debug("Initializing Datapipeline, args: #{inspect(init_arg)}")
    api_token = get_api_token(init_arg.api_key, init_arg.api_secret)
    #Logger.debug("Kraken - Retrieved API token: #{inspect(api_token)}")
    trades_conn_args = init_arg |> Map.put(:channel, :trades) |> Map.put(:destination, self())
    orders_conn_args = init_arg |> Map.put(:channel, :orders) |> Map.put(:api_token, api_token) |> Map.put(:destination, self())
    # Start a supervisor for websocket connections
    {:ok, ws_supervisor} = Supervisor.start_link(
      [
        Supervisor.child_spec({Kraken.WsConnection, trades_conn_args}, id: :trades_conn),
        Supervisor.child_spec({Kraken.WsConnection, orders_conn_args}, id: :orders_conn)
      ],
      strategy: :one_for_one
    )

    {:ok, init_arg |> Map.merge(%{ws_supervisor: ws_supervisor})}
  end

  defp get_api_token(api_key, api_secret) do
    endpoint = "https://api.kraken.com"
    url_path = "/0/private/GetWebSocketsToken"
    payload = %{
      "nonce" => System.system_time(:millisecond)
    }
    signature = get_kraken_signature(url_path, api_secret, payload)
    #Logger.debug("Kraken - API key for token request: #{inspect(api_key)}")
    header = %{
      "API-Key" => api_key,
      "API-Sign" => signature,
    }
    payload = URI.encode_query(payload)
    request = Req.new(method: :post, url: endpoint <> url_path, headers: header, body: payload)
    {request, response} = Req.run!(request)
    response.body |> Map.fetch!("result") |> Map.fetch!("token")
  end

  defp get_kraken_signature(url_path, api_secret, payload) do
    post_data = URI.encode_query(payload)
    nonce = Integer.to_string(payload["nonce"])
    #Logger.debug("Kraken - Post data for signature: #{inspect(post_data)}")
    #Logger.debug("Kraken - Nonce for signature: #{inspect(nonce)}")
    sha256_hash = :crypto.hash(:sha256, nonce <> post_data)
    api_secret = Base.decode64!(api_secret)
    #Logger.debug("Kraken - API secret decoded for signature: #{inspect(api_secret)}")
    #Logger.debug("Kraken - URL path for signature: #{inspect(url_path)}")
    #Logger.debug("Kraken - SHA256 hash for signature: #{inspect(sha256_hash)}")
    signature = :crypto.mac(:hmac, :sha512, api_secret, url_path <> sha256_hash)
    Base.encode64(signature)
  end

  def handle_cast({:trades_snapshot, trade_data}, state) do
    # Process the trade data here
    #IO.inspect(trade_data, label: "Received trade snapshot data")
    {:noreply, state}
  end

  def handle_cast({:trades_update, trade_data}, state) do
    # Process the trade data here
    #IO.inspect(trade_data, label: "Received trade update data")
    {:noreply, state}
  end

  def handle_cast({:order_book_snapshot, order_data}, state) do
    # Process the order data here
    #IO.inspect(order_data, label: "Received order snapshot data")
    {:noreply, state}
  end

  def handle_cast({:order_book_update, order_data}, state) do
    # Process the order data here
    #IO.inspect(order_data, label: "Received order update data")
    {:noreply, state}
  end
end
