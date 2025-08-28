defmodule Mexc.RestApi do
  @behaviour RestApiBase
  require Logger

  def request(method, api_key, api_secret, endpoint, params \\ %{}) do
    uri = "https://api.mexc.com/api/v3" <> endpoint
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    params = params |> Map.put(:timestamp, timestamp)
    signature =
      :crypto.mac(:hmac, :sha256, api_secret, URI.encode_query(params))
      |> Base.encode16(case: :lower)
    query = params |> Map.put(:signature, signature) |> URI.encode_query()
    uri = "#{uri}?#{query}"
    body = ""
    headers = [
      {"X-MEXC-APIKEY", api_key},
      {"Content-Type", "application/json"}
    ]
    #Logger.info("MEXC API Request: #{method} - #{uri}")
    response = HTTPoison.request(method, uri, body, headers)
    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, %{status: status_code, message: Jason.decode!(body)}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %{status: 500, message: reason}}
    end
  end

  def get_listen_key!(api_key, api_secret) do
    response = request(:post, api_key, api_secret, "/userDataStream", %{})
    {:ok, %{"listenKey" => listen_key}} = response
    listen_key
  end

  def get_balances!(api_key, api_secret) do
    {:ok, account_info} = request(:get, api_key, api_secret, "/account", %{})
    account_info["balances"]
  end

  def cancel_open_orders(api_key, api_secret, symbol) do
    request(:delete, api_key, api_secret, "/openOrders", %{"symbol" => symbol})
  end

  def place_order(api_key, api_secret, order_params) do
    request(:post, api_key, api_secret, "/order", order_params)
  end
end
