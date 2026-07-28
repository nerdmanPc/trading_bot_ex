defmodule DataPipeline do
  require Logger
  use GenServer

  def start_link(initial_state \\ %{}) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(init_arg) do
    #Logger.debug("Initializing Datapipeline, args: #{inspect(init_arg)}")
    Dotenv.load()
    init_arg = %{
         symbols: ["BTC/USD", "ETH/USD"],
         api_key: System.get_env("KRAKEN_API_KEY"),
         api_secret: System.get_env("KRAKEN_API_SECRET")
    }
    {:ok, api_token} = Kraken.Auth.get_token(init_arg.api_key, init_arg.api_secret)
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
