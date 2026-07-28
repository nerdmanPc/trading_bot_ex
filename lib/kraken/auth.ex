defmodule Kraken.Auth do
  require Logger

  @spec get_token(String.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def get_token(api_key, api_secret) do
    endpoint = "https://api.kraken.com"
    url_path = "/0/private/GetWebSocketsToken"
    payload = %{"nonce" => System.system_time(:millisecond)}

    signature = get_kraken_signature(url_path, api_secret, payload)

    headers = %{
      "API-Key" => api_key,
      "API-Sign" => signature
    }

    body = URI.encode_query(payload)
    request = Req.new(method: :post, url: endpoint <> url_path, headers: headers, body: body)

    {request, response} = Req.run!(request)

    case response.body do
      %{"result" => %{"token" => token}} -> {:ok, token}
      other -> {:error, {:unexpected_response, other}}
    end
  rescue
    e ->
      Logger.error("Kraken.Auth.get_token failed: #{inspect(e)}")
      {:error, e}
  end

  defp get_kraken_signature(url_path, api_secret, payload) do
    post_data = URI.encode_query(payload)
    nonce = Integer.to_string(payload["nonce"])
    sha256_hash = :crypto.hash(:sha256, nonce <> post_data)
    secret = Base.decode64!(api_secret)
    signature = :crypto.mac(:hmac, :sha512, secret, url_path <> sha256_hash)
    Base.encode64(signature)
  end
end
