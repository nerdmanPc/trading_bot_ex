# TradingBotEx

**A trading bot built in Elixir. It tries to make money by exploiting differences in prices between two exchanges: Binance and MEXC. It doesn't make money, though.**

## Building and Running

In order to build and run the bot, your first step is installing Elixir and the BEAM runtime by following the instructions on this [link](https://elixir-lang.org/install.html).

Then, you will need to generate an API key pair from MEXC by clicking **Apply Now** on this [link](https://www.mexc.com/mexc-api).

Next, create a `.env` file with the following contents:

```
API_KEY = <YOUR_API_KEY>
API_SECRET = <YOUR_API_SECRET>

ASSET_SYMBOL = BTC
QUOTE_SYMBOL = USDC

SPREAD = 0.9995

MIN_NOTIONAL = 1.0
PRICE_PRECISION = 2
QTY_PRECISION = 6
```

To trade with a different symbol, you'll also need to change the last three variables. To do that, send a request like `curl -X GET "https://api.mexc.com/api/v3/exchangeInfo?symbol=<SYMBOL_HERE>"` to get symbol information. Here is where they are in the JSON:
 - `MIN_NOTIONAL` is `quoteAmountPrecision`
 - `PRICE_PRECISION` is `quotePrecision`
 - `QTY_PRECISION` is `baseAssetPrecision`

Spread is the ratio between target MEXC price and current Binance price. A lower value makes the bot more conservative.

After that, we can `mix deps.get` and `mix run --no-halt` to run the bot. Again, this bot did not make money in my tests.