defmodule CryptoPipeline do
  use Application

  @impl true
  def start(_type, _args) do
    Dotenv.load()

    children = [
      {DataPipeline,
       %{
         symbols: ["BTCUSD", "ETHUSD"],
         api_key: System.get_env("KRAKEN_API_KEY"),
         api_secret: System.get_env("KRAKEN_API_SECRET")
       }}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
