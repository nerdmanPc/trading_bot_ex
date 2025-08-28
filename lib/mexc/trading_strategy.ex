defmodule Mexc.TradingStrategy do
  alias Mexc.RestApi
  alias Decimal, as: D
  require Logger
  use GenServer

  def start_link(args) do
    args = Map.merge(%{
      api_key: System.get_env("API_KEY"),
      api_secret: System.get_env("API_SECRET"),
      symbol: System.get_env("ASSET_SYMBOL") <> System.get_env("QUOTE_SYMBOL"),
      spread: System.get_env("SPREAD") |> D.new(),
      min_notional: System.get_env("MIN_NOTIONAL") |> D.new(),
      price_precision: System.get_env("PRICE_PRECISION") |> String.to_integer(),
      qty_precision: System.get_env("QTY_PRECISION") |> String.to_integer()
    }, args || %{})
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

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_cast({:new_candle, status}, config) do
    on_new_candle(status, config)
    {:noreply, config}
  end

  def handle_cast({:new_balance, _status}, config) do
    {:noreply, config}
  end

  def terminate(close_reason, state) do
    Logger.warning("Trading strategy terminated with reason: #{inspect(close_reason)}")
    {:ok, state}
  end

  defp rest_api() do
    Application.get_env(:trading_bot_ex, :mexc_rest_api, RestApi)
  end

  defp should_execute_strategy?(status) do
    status.candles.binance != nil and
    status.candles.mexc != nil and
    (DateTime.diff(status.candles.binance.time, status.candles.mexc.time) |> abs()) < 5
  end

  def on_new_candle(status, config) do
    if should_execute_strategy?(status) do
      binance_price = status.candles.binance.price
      mexc_price = status.candles.mexc.price
      Logger.info("Current spread: #{D.div(mexc_price, binance_price)}")
      target_buy_price = binance_price |> D.mult(config.spread)
      cond do
        D.gte?(mexc_price, binance_price) ->
          #Logger.info("MEXC price (#{mexc_price}) is greater than Binance price (#{binance_price}), placing SELL order.")
          place_sell_order(status, config)
        D.lt?(mexc_price, target_buy_price) ->
          #Logger.info("MEXC price (#{mexc_price}) is less than target buy price (#{target_buy_price}), placing BUY order.")
          place_buy_order(status, config)
        true ->
          #Logger.info("No trading opportunity detected. MEXC price: #{mexc_price}, Binance price: #{binance_price}, Target buy price: #{target_buy_price}.")
          :ok
      end
    else
      :ok
    end
  end

  defp place_sell_order(status, config) do
    sell_price = status.candles.binance.price
    asset_balance = status.balances.asset.free
    sell_quantity = asset_balance |> D.round(config.qty_precision, :down)
    sell_order = %{
      "symbol" => config.symbol,
      "side" => "SELL",
      "type" => "MARKET",
      "quantity" => sell_quantity
    }
    if D.gt?(D.mult(sell_quantity, sell_price), config.min_notional) do
      sell_response = rest_api().place_order(config.api_key, config.api_secret, sell_order)
      Logger.info("Sell order response: #{inspect(sell_response)}")
      :ok
    end
  end

  defp place_buy_order(status, config) do
    #buy_price = status.candles.binance.price |> D.mult(config.spread) |> D.round(config.price_precision, :down)
    quote_balance = status.balances.quote.free
    buy_quantity = quote_balance |> D.round(config.qty_precision, :down)
    buy_order = %{
      "symbol" => config.symbol,
      "side" => "BUY",
      "type" => "MARKET",
      "quoteOrderQty" => buy_quantity
    }

    if D.gt?(buy_quantity, config.min_notional) do
      buy_response = rest_api().place_order(config.api_key, config.api_secret, buy_order)
      Logger.info("Buy order response: #{inspect(buy_response)}")
    end
    :ok
  end
end
