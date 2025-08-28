defmodule RestApiBase do
  @callback place_order(api_key :: String.t(), api_secret :: String.t(), order_params :: map) :: {:ok, map} | {:error, term}
  @callback cancel_open_orders(api_key :: String.t(), api_secret :: String.t(), symbol :: String.t()) :: {:ok, map} | {:error, term}
end
