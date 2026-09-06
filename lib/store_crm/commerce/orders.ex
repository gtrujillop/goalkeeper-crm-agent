defmodule StoreCRM.Commerce.Orders do
  import Ecto.Query
  alias StoreCRM.{Repo, Stores}
  alias StoreCRM.Commerce.{ShopifyEvent, CommerceSession, ProcessOrderWorker}
  alias StoreCRM.CRM.{OrderSummary, Opportunity, FollowUpTask}
  alias StoreCRM.Customers.{Customer, Identity, Phone}

  @topics ~w(orders/create orders/updated orders/paid orders/cancelled orders/fulfilled refunds/create)

  def signature_valid?(body, signature, secret)
      when is_binary(signature) and is_binary(secret) and byte_size(secret) > 0 do
    expected = :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode64()

    byte_size(expected) == byte_size(signature) and
      Plug.Crypto.secure_compare(expected, signature)
  end

  def signature_valid?(_, _, _), do: false

  def accept(store, external_id, topic, payload) when is_map(payload) do
    order_id = if topic == "refunds/create", do: payload["order_id"], else: payload["id"]

    with true <- topic in @topics,
         true <- valid_payload?(topic, payload),
         true <- is_binary(external_id) and byte_size(external_id) in 1..255,
         true <- is_integer(order_id) or (is_binary(order_id) and byte_size(order_id) in 1..255),
         {:ok, occurred_at} <- timestamp(payload["updated_at"] || payload["created_at"]) do
      Repo.transaction(fn ->
        Repo.insert!(
          %ShopifyEvent{
            store_profile_id: store.id,
            external_id: external_id,
            order_id: to_string(order_id),
            topic: topic,
            payload: payload,
            occurred_at: occurred_at
          },
          on_conflict: :nothing,
          conflict_target: [:store_profile_id, :external_id, :topic]
        )

        event =
          Repo.get_by!(ShopifyEvent,
            store_profile_id: store.id,
            external_id: external_id,
            topic: topic
          )

        if event.status != "processed" do
          %{event_id: event.id, store_profile_id: store.id}
          |> ProcessOrderWorker.new(unique: [period: :infinity, fields: [:worker, :args]])
          |> Oban.insert!()
        end

        event
      end)
    else
      _ -> {:error, :invalid_event}
    end
  end

  def accept(_, _, _, _), do: {:error, :invalid_event}

  defp valid_payload?("refunds/create", payload) do
    not is_nil(payload["id"]) and is_list(payload["transactions"] || [])
  end

  defp valid_payload?(_, payload) do
    match?({:ok, _}, timestamp(payload["created_at"])) and
      valid_money?(payload["total_price"]) and
      Enum.all?(
        ~w(note_attributes payment_gateway_names shipping_lines fulfillments line_items),
        &is_list(payload[&1] || [])
      ) and
      (is_nil(payload["customer"]) or is_map(payload["customer"]))
  end

  defp valid_money?(value) when is_binary(value) or is_number(value),
    do: match?({_, ""}, Decimal.parse(to_string(value)))

  defp valid_money?(_), do: false

  def customer_totals(store, customer_id) do
    Repo.all(
      from o in OrderSummary,
        where:
          o.store_profile_id == ^store.id and o.customer_id == ^customer_id and
            not o.reconciliation_required and not is_nil(o.paid_at)
    )
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {currency, orders} ->
      %{
        currency: currency,
        order_count: length(orders),
        lifetime_value:
          Enum.reduce(
            orders,
            Decimal.new(0),
            &Decimal.add(&2, Decimal.sub(&1.total, &1.refunded_total))
          ),
        last_purchase_at: orders |> Enum.map(& &1.paid_at) |> Enum.max(DateTime)
      }
    end)
  end

  def process(store_id, event_id) do
    result =
      Repo.transaction(fn ->
        # Serialize customer correlation and projections per small-store profile.
        Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
          "orders:#{store_id}"
        ])

        event = Repo.get_by!(ShopifyEvent, id: event_id, store_profile_id: store_id)
        store = Stores.get_profile!(store_id)

        events =
          Repo.all(
            from e in ShopifyEvent,
              where: e.store_profile_id == ^store_id and e.order_id == ^event.order_id,
              order_by: [asc: e.occurred_at, asc: e.external_id]
          )

        snapshots = Enum.reject(events, &(&1.topic == "refunds/create"))
        if snapshots == [], do: Repo.rollback(:awaiting_order_snapshot)
        latest = List.last(snapshots)
        order = project(store, latest.payload, events)

        processed_ids = Enum.map(events, & &1.id)

        from(e in ShopifyEvent,
          where: e.store_profile_id == ^store_id and e.id in ^processed_ids
        )
        |> Repo.update_all(set: [status: "processed", error: nil, updated_at: now()])

        order
      end)

    case result do
      {:ok, order} ->
        StoreCRM.Conversations.notify_changed(store_id, order.conversation_id)
        {:ok, order}

      {:error, reason} ->
        from(e in ShopifyEvent, where: e.id == ^event_id and e.store_profile_id == ^store_id)
        |> Repo.update_all(set: [status: "failed", error: inspect(reason)])

        {:error, reason}
    end
  end

  defp project(store, payload, events) do
    order_id = to_string(payload["id"])
    existing = Repo.get_by(OrderSummary, store_profile_id: store.id, shopify_order_id: order_id)
    {customer, session, evidence, conflict?} = correlate(store, payload, existing)

    paid =
      Enum.find(events, &(&1.topic == "orders/paid" or &1.payload["financial_status"] == "paid"))

    cancelled =
      Enum.find(
        events,
        &(&1.topic == "orders/cancelled" or not is_nil(&1.payload["cancelled_at"]))
      )

    fulfilled = Enum.any?(events, &(&1.topic == "orders/fulfilled"))

    refunds =
      events |> Enum.filter(&(&1.topic == "refunds/create")) |> Enum.uniq_by(& &1.payload["id"])

    refunded_total =
      Enum.reduce(refunds, Decimal.new(0), fn e, sum ->
        Enum.reduce(e.payload["transactions"] || [], sum, fn t, acc ->
          if t["status"] == "success" and t["kind"] == "refund",
            do: Decimal.add(acc, money!(t["amount"])),
            else: acc
        end)
      end)

    total = money!(payload["total_price"])

    financial =
      cond do
        Decimal.compare(refunded_total, 0) == :gt ->
          if Decimal.compare(refunded_total, total) == :lt,
            do: "partially_refunded",
            else: "refunded"

        payload["financial_status"] in ["refunded", "partially_refunded", "voided"] ->
          payload["financial_status"]

        paid ->
          "paid"

        true ->
          payload["financial_status"] || "unknown"
      end

    fulfillment =
      if fulfilled, do: "fulfilled", else: payload["fulfillment_status"] || "unfulfilled"

    order = existing || %OrderSummary{store_profile_id: store.id, customer_id: customer.id}

    order =
      order
      |> Ecto.Changeset.change(%{
        customer_id: customer.id,
        conversation_id: session && session.conversation_id,
        opportunity_id: session && session.opportunity_id,
        shopify_order_id: order_id,
        order_name: payload["name"] || "##{order_id}",
        status: if(cancelled, do: "cancelled", else: financial),
        financial_status: financial,
        fulfillment_status: fulfillment,
        total: total,
        currency: payload["currency"] || store.currency,
        shopify_admin_url: "https://#{store.shopify_shop_domain}/admin/orders/#{order_id}",
        placed_at: time!(payload["created_at"]),
        last_synced_at: now(),
        paid_at: paid && paid.occurred_at,
        cancelled_at: cancelled && cancelled.occurred_at,
        payment_path: payment_path(store, payload),
        carrier: carrier(payload),
        identity_evidence: evidence,
        reconciliation_required: conflict?,
        order_channel: if(session, do: "assisted_shopify", else: "direct_shopify"),
        snapshot:
          Map.take(
            payload,
            ~w(line_items payment_gateway_names shipping_lines fulfillments source_name)
          ),
        refunded_total: refunded_total
      })
      |> Repo.insert_or_update!()

    if paid && session && session.opportunity_id && not conflict? do
      from(o in Opportunity,
        where:
          o.id == ^session.opportunity_id and o.store_profile_id == ^store.id and
            o.customer_id == ^customer.id
      )
      |> Repo.update_all(set: [stage: "won", updated_at: now()])
    end

    order
  end

  defp correlate(store, payload, existing) do
    token =
      Enum.find_value(payload["note_attributes"] || [], fn a ->
        if a["name"] == "gk_correlation", do: a["value"]
      end)

    session =
      if is_binary(token) do
        case Phoenix.Token.verify(StoreCRMWeb.Endpoint, "commerce", token, max_age: :infinity) do
          {:ok, _} ->
            Repo.get_by(CommerceSession, store_profile_id: store.id, correlation_token: token)

          _ ->
            nil
        end
      end

    session =
      session ||
        if is_nil(token) && existing && existing.identity_evidence["commerce_session_id"] do
          Repo.get_by(CommerceSession,
            store_profile_id: store.id,
            id: existing.identity_evidence["commerce_session_id"]
          )
        end

    shopify_id = get_in(payload, ["customer", "id"])

    identity =
      if shopify_id,
        do:
          Repo.get_by(Identity,
            store_profile_id: store.id,
            provider: "shopify",
            external_id: to_string(shopify_id)
          )

    email = normalize_email(payload["email"] || get_in(payload, ["customer", "email"]))

    phone =
      case Phone.normalize(
             payload["phone"] || get_in(payload, ["customer", "phone"]) || "",
             store.phone_region
           ) do
        {:ok, value} -> value
        _ -> nil
      end

    phone_customers =
      if phone,
        do:
          Repo.all(
            from i in Identity,
              where:
                i.store_profile_id == ^store.id and i.provider == "whatsapp" and
                  i.normalized_value == ^phone,
              select: i.customer_id
          ),
        else: []

    email_customers =
      if email,
        do:
          Repo.all(
            from c in Customer,
              where:
                c.store_profile_id == ^store.id and fragment("lower(?)", c.email) == ^email and
                  c.profile_confidence == "confirmed",
              select: c.id
          ),
        else: []

    ids =
      Enum.uniq(
        Enum.reject(
          [session && session.customer_id, identity && identity.customer_id] ++
            phone_customers ++ email_customers,
          &is_nil/1
        )
      )

    candidate =
      case ids do
        [id] -> Repo.get_by!(Customer, id: id, store_profile_id: store.id)
        _ -> nil
      end

    contradictory_email? =
      candidate && email && candidate.email && normalize_email(candidate.email) != email

    conflict? =
      length(ids) > 1 or !!contradictory_email? or (not is_nil(token) and is_nil(session))

    customer =
      cond do
        existing ->
          Repo.get_by!(Customer, id: existing.customer_id, store_profile_id: store.id)

        candidate && not conflict? ->
          candidate

        true ->
          Repo.insert!(%Customer{
            store_profile_id: store.id,
            name: get_in(payload, ["customer", "first_name"]),
            email: email,
            first_interaction_at: now(),
            last_interaction_at: now()
          })
      end

    conflict? =
      conflict? or (existing != nil and existing.reconciliation_required) or
        (candidate != nil and candidate.id != customer.id)

    if shopify_id && is_nil(identity) && not conflict? do
      Repo.insert!(%Identity{
        store_profile_id: store.id,
        customer_id: customer.id,
        provider: "shopify",
        external_id: to_string(shopify_id),
        normalized_value: to_string(shopify_id)
      })
    end

    source =
      cond do
        conflict? -> "conflicting_identity"
        session -> "signed_commerce_session"
        identity -> "shopify_customer_id"
        candidate -> "normalized_identity"
        true -> "new_shopify_customer"
      end

    {customer, if(conflict?, do: nil, else: session),
     %{
       "source" => source,
       "candidate_ids" => ids,
       "commerce_session_id" => session && session.id,
       "confidence" => if(conflict?, do: "review_required", else: "deterministic")
     }, conflict?}
  end

  def start_follow_up(store, order_id) do
    Repo.transaction(fn ->
      order =
        Repo.one!(
          from o in OrderSummary,
            where: o.id == ^order_id and o.store_profile_id == ^store.id,
            lock: "FOR UPDATE"
        )

      if order.reconciliation_required, do: Repo.rollback(:identity_review_required)
      existing = Repo.get_by(FollowUpTask, store_profile_id: store.id, order_summary_id: order.id)

      existing ||
        Repo.insert!(%FollowUpTask{
          store_profile_id: store.id,
          customer_id: order.customer_id,
          conversation_id: order.conversation_id,
          order_summary_id: order.id,
          title: "Confirmar entrega #{order.order_name}",
          due_at: DateTime.add(now(), 86400),
          status: "open"
        })
    end)
  end

  defp payment_path(store, payload) do
    gateways = Enum.map(payload["payment_gateway_names"] || [], &String.downcase/1)
    configured = Map.get(store.agent_limits, "payment_paths", %{})

    Enum.find_value(gateways, "unknown", fn name ->
      configured[name] ||
        cond do
          String.contains?(name, ["mercado pago", "mercadopago"]) ->
            "mercado_pago_shopify"

          String.contains?(name, ["bank transfer", "transferencia bancaria"]) ->
            "bank_transfer"

          String.contains?(name, ["cash on delivery", "contra entrega", "contraentrega", "cod"]) ->
            "collect_on_delivery"

          true ->
            nil
        end
    end)
  end

  defp carrier(payload) do
    Enum.find_value(payload["fulfillments"] || [], & &1["tracking_company"]) ||
      Enum.find_value(payload["shipping_lines"] || [], fn line ->
        if String.contains?(String.downcase(line["title"] || ""), "tcc"), do: "TCC"
      end)
  end

  defp normalize_email(value) when is_binary(value),
    do: value |> String.trim() |> String.downcase()

  defp normalize_email(_), do: nil

  defp money!(value) do
    case Decimal.parse(to_string(value)) do
      {decimal, ""} -> decimal
      _ -> Repo.rollback(:invalid_money)
    end
  end

  defp timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _} -> {:ok, DateTime.truncate(time, :second)}
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp timestamp(_), do: {:error, :invalid_timestamp}

  defp time!(value) do
    case timestamp(value) do
      {:ok, time} -> time
      _ -> Repo.rollback(:invalid_timestamp)
    end
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
