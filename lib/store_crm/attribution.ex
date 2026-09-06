defmodule StoreCRM.Attribution do
  import Ecto.Query
  alias StoreCRM.{Repo, CRM.OrderSummary}
  alias StoreCRM.Attribution.Touchpoint

  def create_redirect(store, params) do
    now = now()
    id = Ecto.UUID.generate()
    token = Phoenix.Token.sign(StoreCRMWeb.Endpoint, "acquisition", {store.id, id})

    touch =
      Repo.insert!(%Touchpoint{
        id: id,
        store_profile_id: store.id,
        source: "google",
        confidence: "redirect_token",
        evidence_key: "redirect:#{id}",
        evidence:
          Map.take(
            params,
            ~w(utm_source utm_medium utm_campaign utm_content utm_term gclid gbraid wbraid)
          ),
        occurred_at: now,
        expires_at: DateTime.add(now, 3600)
      })

    {touch, token}
  end

  def capture(store, result) do
    message = result.message
    referral = message.raw_payload["referral"]

    if is_map(referral) and map_size(referral) > 0 do
      Repo.insert!(
        %Touchpoint{
          store_profile_id: store.id,
          customer_id: message.customer_id,
          conversation_id: message.conversation_id,
          source: "meta",
          confidence: "provider_referral",
          evidence_key: "message:#{message.id}",
          evidence: referral,
          occurred_at: message.occurred_at,
          resolved_at: now()
        },
        on_conflict: :nothing,
        conflict_target: [:store_profile_id, :evidence_key]
      )
    end

    case Regex.run(~r/\[gk:([A-Za-z0-9_.-]+)\]/, message.content || "") do
      [_, token] -> resolve_token(store, token, message)
      _ -> :ok
    end

    :ok
  end

  defp resolve_token(store, token, message) do
    with {:ok, {store_id, id}} <-
           Phoenix.Token.verify(StoreCRMWeb.Endpoint, "acquisition", token, max_age: 3600),
         true <- store_id == store.id do
      from(t in Touchpoint,
        where:
          t.id == ^id and t.store_profile_id == ^store.id and
            is_nil(t.customer_id) and t.expires_at >= ^now()
      )
      |> Repo.update_all(
        set: [
          customer_id: message.customer_id,
          conversation_id: message.conversation_id,
          resolved_at: now()
        ]
      )
    end
  end

  def evidence(order) do
    touches =
      if order.reconciliation_required do
        []
      else
        Repo.all(
          from t in Touchpoint,
            where:
              t.store_profile_id == ^order.store_profile_id and
                t.customer_id == ^order.customer_id and t.occurred_at <= ^order.placed_at,
            order_by: [asc: t.occurred_at, asc: t.id]
        )
      end

    %{first: List.first(touches), last: List.last(touches)}
  end

  def report(store) do
    Repo.all(
      from o in OrderSummary,
        where: o.store_profile_id == ^store.id,
        order_by: [desc: o.placed_at]
    )
    |> Enum.map(fn order ->
      Map.merge(%{id: order.id, order: order, events: events(order)}, evidence(order))
    end)
  end

  defp events(%{order_channel: "whatsapp"} = order) do
    Repo.all(
      from e in StoreCRM.Commerce.NativeOrderEvent,
        where: e.store_profile_id == ^order.store_profile_id and e.order_summary_id == ^order.id,
        order_by: [asc: e.order_version],
        select: %{
          id: e.id,
          topic: e.kind,
          actor: e.actor,
          evidence: e.evidence,
          occurred_at: e.inserted_at
        }
    )
  end

  defp events(order) do
    Repo.all(
      from e in StoreCRM.Commerce.ShopifyEvent,
        where:
          e.store_profile_id == ^order.store_profile_id and e.order_id == ^order.shopify_order_id,
        order_by: [asc: e.occurred_at],
        select: %{id: e.external_id, topic: e.topic, status: e.status, occurred_at: e.occurred_at}
    )
  end

  def revenue(rows, model) when model in [:first, :last] do
    rows
    |> Enum.filter(& &1.order.paid_at)
    |> Enum.group_by(fn row ->
      touch = Map.fetch!(row, model)
      {row.order.currency, if(touch, do: touch.source, else: "unknown")}
    end)
    |> Enum.map(fn {{currency, source}, group} ->
      %{
        currency: currency,
        source: source,
        orders: length(group),
        revenue: Enum.reduce(group, Decimal.new(0), &Decimal.add(&2, &1.order.total))
      }
    end)
    |> Enum.sort_by(&{&1.currency, &1.source})
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
