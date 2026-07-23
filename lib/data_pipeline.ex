defmodule DataPipeline do
  use GenServer

  def start_link(initial_state \\ %{}) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  def init(init_arg) do
    {:ok, trades_pid} =
      Kraken.WsConnection.start_link(
        init_arg
        |> Map.put(:channel, :trades)
        |> Map.put(:destination, self())
      )

    {:ok, orders_pid} =
      Kraken.WsConnection.start_link(
        init_arg
        |> Map.put(:channel, :orders)
        |> Map.put(:destination, self())
      )

    {:ok, init_arg |> Map.merge(%{trades_pid: trades_pid, orders_pid: orders_pid})}
  end

  def handle_cast({:trade_data, trade_data}, state) do
    # Process the trade data here
    IO.inspect(trade_data, label: "Received trade data")
    {:noreply, state}
  end

  def handle_cast({:order_data, order_data}, state) do
    # Process the order data here
    IO.inspect(order_data, label: "Received order data")
    {:noreply, state}
  end
end
