defmodule Kraken.Subscription do
  @moduledoc """
  Registry-based pub/sub for Kraken WebSocket trade stream updates.

  Other processes can subscribe to a topic such as the asset pair and receive
  broadcast messages when the Kraken trade stream publishes snapshots or updates.
  """

  @registry __MODULE__.Registry

  @type topic :: atom() | String.t()
  @type message :: any()

  @spec child_spec(any()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    Registry.child_spec(keys: :duplicate, name: @registry)
  end

  @spec subscribe(topic()) :: {:ok, pid()} | {:error, any()}
  def subscribe(topic) when is_atom(topic) or is_binary(topic) do
    Registry.register(@registry, topic, nil)
  end

  @spec unsubscribe(topic()) :: :ok
  def unsubscribe(topic) when is_atom(topic) or is_binary(topic) do
    Registry.unregister(@registry, topic)
  end

  @spec broadcast(topic(), message()) :: :ok
  def broadcast(topic, message) when is_atom(topic) or is_binary(topic) do
    Registry.dispatch(@registry, topic, fn entries ->
      for {pid, _value} <- entries do
        send(pid, message)
      end
    end)
  end
end
