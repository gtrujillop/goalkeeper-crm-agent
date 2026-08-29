defmodule StoreCRM.Conversations.ProcessInboundWorker do
  use Oban.Worker, queue: :inbound_messages, max_attempts: 5

  alias StoreCRM.Agent.Engine
  alias StoreCRM.Stores

  def new_for_store(store_profile, message_attrs, opts \\ []) when not is_nil(store_profile.id) do
    args = %{"store_profile_id" => store_profile.id, "message" => stringify_keys(message_attrs)}
    new(args, opts)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"store_profile_id" => store_profile_id, "message" => attrs}}) do
    store = Stores.get_profile!(store_profile_id)

    attrs = %{
      source: Map.fetch!(attrs, "source"),
      provider_message_id: Map.fetch!(attrs, "provider_message_id"),
      phone: Map.fetch!(attrs, "phone"),
      content: Map.fetch!(attrs, "content"),
      raw_payload: Map.get(attrs, "raw_payload", %{})
    }

    case Engine.process_inbound(store, attrs) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def perform(%Oban.Job{}), do: {:discard, :store_profile_required}

  defp stringify_keys(attrs), do: Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
end
