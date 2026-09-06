defmodule StoreCRM.Commerce.IntegrationMonitor do
  import Ecto.Query
  alias StoreCRM.Repo
  alias StoreCRM.Commerce.ShopifyEvent
  alias StoreCRM.CRM.OrderSummary
  alias StoreCRM.Attribution.Touchpoint

  def snapshot(store) do
    statuses =
      Repo.all(
        from e in ShopifyEvent,
          where: e.store_profile_id == ^store.id,
          group_by: e.status,
          select: {e.status, count(e.id)}
      )
      |> Map.new()

    %{
      native_orders:
        Repo.aggregate(
          from(o in OrderSummary,
            where: o.store_profile_id == ^store.id and o.order_channel == "whatsapp"
          ),
          :count
        ),
      native_transfer_pending:
        Repo.aggregate(
          from(o in OrderSummary,
            where:
              o.store_profile_id == ^store.id and o.order_channel == "whatsapp" and
                o.status != "cancelled" and o.financial_status == "pending_transfer"
          ),
          :count
        ),
      native_cod_pending:
        Repo.aggregate(
          from(o in OrderSummary,
            where:
              o.store_profile_id == ^store.id and o.order_channel == "whatsapp" and
                o.status != "cancelled" and o.financial_status == "collect_on_delivery"
          ),
          :count
        ),
      pending: Map.get(statuses, "pending", 0),
      processed: Map.get(statuses, "processed", 0),
      failed: Map.get(statuses, "failed", 0),
      orders:
        Repo.aggregate(from(o in OrderSummary, where: o.store_profile_id == ^store.id), :count),
      review:
        Repo.aggregate(
          from(o in OrderSummary,
            where: o.store_profile_id == ^store.id and o.reconciliation_required
          ),
          :count
        ),
      last_received_at:
        Repo.one(
          from e in ShopifyEvent,
            where: e.store_profile_id == ^store.id,
            select: max(e.inserted_at)
        ),
      meta:
        Repo.aggregate(
          from(t in Touchpoint, where: t.store_profile_id == ^store.id and t.source == "meta"),
          :count
        ),
      google_visits:
        Repo.aggregate(
          from(t in Touchpoint, where: t.store_profile_id == ^store.id and t.source == "google"),
          :count
        ),
      google_resolved:
        Repo.aggregate(
          from(t in Touchpoint,
            where:
              t.store_profile_id == ^store.id and t.source == "google" and
                not is_nil(t.customer_id)
          ),
          :count
        ),
      events:
        Repo.all(
          from e in ShopifyEvent,
            where: e.store_profile_id == ^store.id,
            order_by: [desc: e.inserted_at, desc: e.id],
            limit: 20,
            select: %{
              id: e.id,
              external_id: e.external_id,
              order_id: e.order_id,
              topic: e.topic,
              status: e.status,
              error: e.error,
              inserted_at: e.inserted_at
            }
        )
    }
  end
end
