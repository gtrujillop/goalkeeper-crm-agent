defmodule StoreCRM.Commerce.ProcessOrderWorker do
  use Oban.Worker, queue: :integrations, max_attempts: 10
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"store_profile_id" => store_id, "event_id" => event_id}}) do
    case StoreCRM.Commerce.Orders.process(store_id, event_id) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
