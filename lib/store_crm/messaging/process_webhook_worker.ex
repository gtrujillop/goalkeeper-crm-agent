defmodule StoreCRM.Messaging.ProcessWebhookWorker do
  use Oban.Worker, queue: :inbound_messages, max_attempts: 5
  alias StoreCRM.Messaging.WebhookEvent
  alias StoreCRM.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => id}}) do
    case Repo.get(WebhookEvent, id) do
      %WebhookEvent{status: "processed"} -> :ok
      %WebhookEvent{} = event -> serialized_process(event)
      nil -> {:discard, :event_not_found}
    end
  end

  def perform(_), do: {:discard, :event_id_required}

  defp serialized_process(event) do
    serialization_key =
      "#{event.whatsapp_account_id}:#{event.payload["from"] || event.payload["recipient_id"] || event.payload["id"]}"

    Repo.transaction(fn ->
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
        [serialization_key]
      )

      case StoreCRM.Messaging.process_event(event) do
        :ok -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
