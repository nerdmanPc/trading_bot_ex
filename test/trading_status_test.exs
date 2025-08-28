defmodule Mexc.TradingStatusTest do
  use ExUnit.Case
  import Mexc.TradingStatus
  doctest Mexc.TradingStatus

  setup %{} do
    init_args = %{
      asset_symbol: "BTC",
      quote_symbol: "USDT",
      asset_balance: Decimal.new("1.0"),
      quote_balance: Decimal.new("1.0")
    }
    initial_state = initial_state(init_args)

    %{initial_state: initial_state}
  end

  test "Updates Binance candle when closed", %{initial_state: initial_state} do
    candle = %{ price: Decimal.new("100.0"), time: ~U[2023-01-01 00:00:00Z], closed: true }
    new_state = update_binance_candle(candle, initial_state)

    assert new_state.candles.binance == candle
  end

  test "Updates MEXC open candle when absent", %{initial_state: initial_state} do
    candle = %{ price: Decimal.new("100.0"), time: ~U[2023-01-01 00:00:00Z] }
    new_state = update_mexc_candle(candle, initial_state)

    assert new_state.candles.mexc.open == candle
  end

  test "Updates MEXC open candle when present", %{initial_state: initial_state} do
    first_candle = %{ price: Decimal.new("100.0"), time: ~U[2023-01-01 00:00:00Z] }
    initial_state = update_mexc_candle(first_candle, initial_state)

    second_candle = %{ price: Decimal.new("101.0"), time: ~U[2023-01-01 00:00:00Z] }
    new_state = update_mexc_candle(second_candle, initial_state)

    assert new_state.candles.mexc.open == second_candle
  end

  test "Updates MEXC candles when next open candle is recieved", %{initial_state: initial_state} do
    first_candle = %{ price: Decimal.new("100.0"), time: ~U[2023-01-01 00:00:00Z] }
    initial_state = update_mexc_candle(first_candle, initial_state)

    second_candle = %{ price: Decimal.new("101.0"), time: ~U[2023-01-01 00:01:00Z] }
    new_state = update_mexc_candle(second_candle, initial_state)

    assert new_state.candles.mexc.closed == first_candle
    assert new_state.candles.mexc.open == second_candle
  end

  test "Updates asset balance when account data is recieved", %{initial_state: initial_state} do
    account_data = %{ symbol: "BTC", free: Decimal.new("1.0"), locked: Decimal.new("0.0") }
    new_state = update_balance(account_data, initial_state)

    assert new_state.balances.asset == %{free: Decimal.new("1.0"), locked: Decimal.new("0.0")}
  end

  test "Updates quote balance when account data is recieved", %{initial_state: initial_state} do
    account_data = %{ symbol: "USDT", free: Decimal.new("1.0"), locked: Decimal.new("0.0") }
    new_state = update_balance(account_data, initial_state)

    assert new_state.balances.quote == %{free: Decimal.new("1.0"), locked: Decimal.new("0.0")}
  end

  test "Ignores unrelated account updates", %{initial_state: initial_state} do
    account_data = %{ symbol: "ETH", free: Decimal.new("2.0"), locked: Decimal.new("1.0") }
    new_state = update_balance(account_data, initial_state)

    assert new_state.balances.quote == %{free: Decimal.new("1.0"), locked: Decimal.new("0.0")}
    assert new_state.balances.quote == %{free: Decimal.new("1.0"), locked: Decimal.new("0.0")}
  end
end
