defmodule TradingStrategyTest do
  use ExUnit.Case
  import Mexc.TradingStrategy
  alias Decimal, as: D
  doctest Mexc.TradingStrategy

  test "Should cancel all open orders and place correct maker order pair when status update is recieved" do
    status = %{
      candles: %{
        binance: %{ price: D.new("100.0"), time: ~U[2023-01-01 00:00:59Z] },
        mexc: %{ price: D.new("99.5"), time: ~U[2023-01-01 00:01:00Z] }
      },
      balances: %{
        asset: %{ free: D.new("1.0"), locked: D.new("0.0") },
        quote: %{ free: D.new("1.0"), locked: D.new("0.0") }
      }
    }
    config = %{
      api_key: nil,
      api_secret: nil,
      symbol: "BTCUSDT",
      min_notional: D.new("10.0"),
      price_precision: 2,
      qty_precision: 3,
      spread: D.new("0.99")
    }

    Mox.expect(RestApiMock, :cancel_open_orders, 1, fn _api_key, _api_secret, symbol ->
      assert symbol == "BTCUSDT"
      :ok
    end)
    Mox.expect(RestApiMock, :place_order, 1, fn _api_key, _api_secret, params ->
      assert params[:side] == "BUY"
      assert params[:symbol] == "BTCUSDT"
      assert params[:type] == "LIMIT_MAKER"
      assert D.eq?(params[:price], D.new("99.0"))
      assert D.eq?(params[:quantity], D.div(D.new("1.0"), D.new("99.0")) |> D.round(3, :down))
      :ok
    end)
    Mox.expect(RestApiMock, :place_order, 1, fn _api_key, _api_secret, params ->
      assert params[:side] == "SELL"
      assert params[:symbol] == "BTCUSDT"
      assert params[:type] == "LIMIT_MAKER"
      assert D.eq?(params[:price], D.new("100.0"))
      assert D.eq?(params[:quantity], D.new("1.0"))
      :ok
    end)

    execute_strategy(status, config)

    Mox.verify!()
  end

  test "Should do nothing when Binance candle is nil" do
    status = %{
      candles: %{
        binance: nil,
        mexc: %{ price: D.new("99.5"), time: ~U[2023-01-01 00:00:00Z] }
      },
      balances: %{
        asset: %{ free: D.new("1.0"), locked: D.new("0.0") },
        quote: %{ free: D.new("1.0"), locked: D.new("0.0") }
      }
    }
    config = %{
      api_key: nil,
      api_secret: nil,
      symbol: "BTCUSDT",
      spread: D.new("0.99")
    }

    Mox.expect(RestApiMock, :cancel_open_orders, 0, fn _api_key, _api_secret, symbol -> :ok end)
    Mox.expect(RestApiMock, :place_order, 0, fn _api_key, _api_secret, params -> :ok end)

    execute_strategy(status, config)

    Mox.verify!()
  end

  test "Should do nothing when MEXC candle is nil" do
    status = %{
      candles: %{
        binance: %{ price: D.new("100.0"), time: ~U[2023-01-01 00:00:00Z] },
        mexc: nil
      },
      balances: %{
        asset: %{ free: D.new("1.0"), locked: D.new("0.0") },
        quote: %{ free: D.new("1.0"), locked: D.new("0.0") }
      }
    }
    config = %{
      api_key: nil,
      api_secret: nil,
      symbol: "BTCUSDT",
      spread: D.new("0.99")
    }

    Mox.expect(RestApiMock, :cancel_open_orders, 0, fn _api_key, _api_secret, symbol -> :ok end)
    Mox.expect(RestApiMock, :place_order, 0, fn _api_key, _api_secret, params -> :ok end)

    execute_strategy(status, config)

    Mox.verify!()
  end

  test "Should do nothing when one candle is outdated" do
    status = %{
      candles: %{
        binance: %{ price: D.new("100.0"), time: ~U[2023-01-01 00:00:00Z] },
        mexc: %{ price: D.new("99.5"), time: ~U[2023-01-01 00:01:00Z] }
      },
      balances: %{
        asset: %{ free: D.new("1.0"), locked: D.new("0.0") },
        quote: %{ free: D.new("1.0"), locked: D.new("0.0") }
      }
    }
    config = %{
      api_key: nil,
      api_secret: nil,
      symbol: "BTCUSDT",
      spread: D.new("0.99")
    }

    Mox.expect(RestApiMock, :cancel_open_orders, 0, fn _api_key, _api_secret, symbol -> :ok end)
    Mox.expect(RestApiMock, :place_order, 0, fn _api_key, _api_secret, params -> :ok end)

    execute_strategy(status, config)

    Mox.verify!()
  end

  #TODO: Do nothing when quantity is 0
end
