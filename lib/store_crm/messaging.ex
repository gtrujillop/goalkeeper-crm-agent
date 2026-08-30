defmodule StoreCRM.Messaging do
  import Ecto.Query
  alias StoreCRM.Repo
  alias StoreCRM.Conversations.{Conversation, Message}
  alias StoreCRM.Messaging.{DeliveryEvent, WebhookEvent, WhatsAppAccount, ProcessWebhookWorker}

  def create_account(store, attrs) do
    %WhatsAppAccount{store_profile_id: store.id}
    |> WhatsAppAccount.changeset(attrs)
    |> Repo.insert()
  end

  def accept_webhook(payload) do
    with {:ok, events} <- normalize(payload),
         {:ok, persisted} <- persist_events(events) do
      Enum.each(persisted, fn
        %{duplicate?: false, event: event} ->
          %{"event_id" => event.id}
          |> ProcessWebhookWorker.new(unique: [period: :infinity])
          |> Oban.insert()

        _ ->
          :ok
      end)

      {:ok, persisted}
    end
  end

  def process_event(%WebhookEvent{kind: "message"} = event) do
    store = StoreCRM.Stores.get_profile!(event.store_profile_id)
    message = event.payload
    adapter = Application.get_env(:store_crm, :whatsapp, [])[:adapter] || StoreCRM.Messaging.Fake

    result =
      StoreCRM.Agent.Engine.process_inbound(
        store,
        %{
          source: "whatsapp",
          provider_message_id: message["id"],
          phone: message["from"],
          content: get_in(message, ["text", "body"]),
          occurred_at: unix_time(message["timestamp"]),
          raw_payload: message
        },
        messaging_adapter: adapter
      )

    complete_event(event, result)
  end

  def process_event(%WebhookEvent{kind: "status"} = event) do
    status = event.payload
    message = Repo.get_by(Message, source: "agent", provider_message_id: status["id"])

    result =
      if message do
        now = unix_time(status["timestamp"])

        %DeliveryEvent{store_profile_id: event.store_profile_id, message_id: message.id}
        |> DeliveryEvent.changeset(%{
          status: status["status"],
          provider_event_id: event.external_id,
          occurred_at: now,
          details: status
        })
        |> Repo.insert(on_conflict: :nothing)

        message |> Message.changeset(%{status: status["status"]}) |> Repo.update()
      else
        {:ok, :ignored_unknown_outbound_message}
      end

    complete_event(event, result)
  end

  def take_over(store, conversation_id) do
    from(c in Conversation, where: c.id == ^conversation_id and c.store_profile_id == ^store.id)
    |> Repo.update_all(
      set: [state: "human_owned", updated_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
    |> case do
      {1, _} -> {:ok, Repo.get!(Conversation, conversation_id)}
      _ -> {:error, :not_found}
    end
  end

  def signature_valid?(raw_body, "sha256=" <> supplied, secret)
      when is_binary(secret) and byte_size(secret) > 0 do
    expected = :crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower)
    byte_size(expected) == byte_size(supplied) and Plug.Crypto.secure_compare(expected, supplied)
  end

  def signature_valid?(_, _, _), do: false

  defp normalize(%{"object" => "whatsapp_business_account", "entry" => entries}) do
    events =
      for entry <- entries,
          change <- entry["changes"] || [],
          change["field"] == "messages",
          value = change["value"],
          item <- normalized_items(value),
          do: Map.put(item, :phone_number_id, get_in(value, ["metadata", "phone_number_id"]))

    if events == [] or Enum.any?(events, &is_nil(&1.phone_number_id)),
      do: {:error, :unsupported_payload},
      else: {:ok, events}
  end

  defp normalize(_), do: {:error, :unsupported_payload}

  defp normalized_items(value) do
    messages =
      for %{"id" => id, "type" => "text"} = item <- value["messages"] || [],
          do: %{external_id: id, kind: "message", payload: item}

    statuses =
      for %{"id" => id, "status" => status} = item <- value["statuses"] || [],
          do: %{
            external_id: "#{id}:#{status}:#{item["timestamp"]}",
            kind: "status",
            payload: item
          }

    messages ++ statuses
  end

  defp persist_events(events) do
    Repo.transaction(fn -> Enum.map(events, &persist_event/1) end)
    |> case do
      {:ok, rows} -> {:ok, rows}
      {:error, reason} -> {:error, reason}
    end
  end

  defp persist_event(attrs) do
    account =
      Repo.get_by(WhatsAppAccount, phone_number_id: attrs.phone_number_id, active: true) ||
        Repo.rollback(:unknown_phone_number)

    event =
      %WebhookEvent{store_profile_id: account.store_profile_id, whatsapp_account_id: account.id}
      |> WebhookEvent.changeset(attrs)

    case Repo.insert(event,
           on_conflict: :nothing,
           conflict_target: [:whatsapp_account_id, :external_id, :kind]
         ) do
      {:ok, %{id: id} = event} when not is_nil(id) ->
        %{duplicate?: false, event: event}

      {:ok, _} ->
        existing =
          Repo.get_by!(WebhookEvent,
            whatsapp_account_id: account.id,
            external_id: attrs.external_id,
            kind: attrs.kind
          )

        %{duplicate?: true, event: existing}

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  defp complete_event(event, :ok), do: complete_event(event, {:ok, %{}})

  defp complete_event(event, {:ok, _}) do
    event
    |> WebhookEvent.changeset(%{
      status: "processed",
      processed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()

    :ok
  end

  defp complete_event(event, {:error, reason}) do
    event |> WebhookEvent.changeset(%{status: "failed", error: inspect(reason)}) |> Repo.update()
    {:error, reason}
  end

  defp unix_time(value) when is_binary(value),
    do: value |> String.to_integer() |> DateTime.from_unix!()

  defp unix_time(_), do: DateTime.utc_now() |> DateTime.truncate(:second)
end
