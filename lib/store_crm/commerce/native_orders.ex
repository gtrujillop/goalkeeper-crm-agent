defmodule StoreCRM.Commerce.NativeOrders do
  import Ecto.Query
  alias StoreCRM.{Repo, Conversations}
  alias StoreCRM.Commerce.{NativeOrderForm, NativeOrderItem, NativeOrderEvent}
  alias StoreCRM.Conversations.Conversation
  alias StoreCRM.CRM.{OrderSummary, Opportunity}
  alias StoreCRM.Customers.{Identity, Phone}

  def conversation!(store, id),
    do: Repo.get_by!(Conversation, store_profile_id: store.id, id: id) |> Repo.preload(:customer)

  def initial_form(store, conversation) do
    identity =
      Repo.one(
        from i in Identity,
          where:
            i.store_profile_id == ^store.id and i.customer_id == ^conversation.customer_id and
              i.provider == "whatsapp",
          limit: 1
      )

    %NativeOrderForm{
      recipient: conversation.customer.name,
      phone: identity && identity.normalized_value,
      items: [%NativeOrderItem{}]
    }
    |> NativeOrderForm.changeset(%{})
  end

  def opportunities(store, customer_id),
    do:
      Repo.all(
        from o in Opportunity,
          where:
            o.store_profile_id == ^store.id and o.customer_id == ^customer_id and
              o.stage not in ["won", "lost"],
          order_by: [desc: o.inserted_at]
      )

  def create(store, conversation_id, request_id, attrs, actor) do
    changeset = NativeOrderForm.changeset(%NativeOrderForm{}, attrs)

    with {:ok, _} <- Ecto.UUID.cast(request_id),
         {:ok, form} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, phone} <- Phone.normalize(form.phone, store.phone_region),
         true <- is_binary(actor) and byte_size(actor) in 1..200 do
      Repo.transaction(fn ->
        conversation =
          Repo.one!(
            from c in Conversation,
              where: c.id == ^conversation_id and c.store_profile_id == ^store.id,
              lock: "FOR UPDATE"
          )

        existing =
          Repo.get_by(OrderSummary, store_profile_id: store.id, native_request_id: request_id)

        if existing do
          if existing.conversation_id != conversation.id, do: Repo.rollback(:request_conflict)
          existing
        else
          if form.opportunity_id do
            unless Repo.exists?(
                     from o in Opportunity,
                       where:
                         o.id == ^form.opportunity_id and o.store_profile_id == ^store.id and
                           o.customer_id == ^conversation.customer_id and
                           o.stage not in ["won", "lost"]
                   ),
                   do: Repo.rollback(:invalid_opportunity)
          end

          items =
            Enum.map(form.items, fn item ->
              %{
                "title" => item.title,
                "variant" => item.variant,
                "quantity" => item.quantity,
                "unit_price" => Decimal.to_string(item.unit_price),
                "line_total" => Decimal.to_string(Decimal.mult(item.unit_price, item.quantity))
              }
            end)

          total =
            Enum.reduce(
              form.items,
              form.shipping_cost,
              &Decimal.add(&2, Decimal.mult(&1.unit_price, &1.quantity))
            )

          order_id = Ecto.UUID.generate()

          order =
            Repo.insert!(%OrderSummary{
              id: order_id,
              store_profile_id: store.id,
              customer_id: conversation.customer_id,
              conversation_id: conversation.id,
              opportunity_id: form.opportunity_id,
              native_request_id: request_id,
              order_channel: "whatsapp",
              order_name: "WA-#{String.slice(order_id, 0, 8) |> String.upcase()}",
              status: "confirmed",
              financial_status:
                if(form.payment_path == "bank_transfer",
                  do: "pending_transfer",
                  else: "collect_on_delivery"
                ),
              payment_path: form.payment_path,
              fulfillment_status: "unfulfilled",
              carrier: form.carrier,
              total: total,
              currency: store.currency,
              placed_at: now(),
              last_synced_at: now(),
              identity_evidence: %{
                "source" => "manager_conversation",
                "confidence" => "explicit",
                "conversation_id" => conversation.id
              },
              snapshot: %{
                "line_items" => items,
                "shipping_cost" => Decimal.to_string(form.shipping_cost),
                "recipient" => form.recipient,
                "phone" => phone,
                "address" => form.address,
                "city" => form.city,
                "notes" => form.notes
              }
            })

          audit!(order, actor, "order.confirmed", %{
            "total" => Decimal.to_string(total),
            "currency" => store.currency,
            "payment_path" => form.payment_path
          })

          order
        end
      end)
      |> notify(store)
    else
      {:error, %Ecto.Changeset{} = errors} ->
        {:error, errors}

      {:error, _} ->
        {:error,
         Ecto.Changeset.add_error(
           changeset,
           :phone,
           "Revisa el número de teléfono con su indicativo"
         )
         |> Map.put(:action, :insert)}

      _ ->
        {:error, :invalid_request}
    end
  end

  def get!(store, id),
    do: Repo.get_by!(OrderSummary, id: id, store_profile_id: store.id, order_channel: "whatsapp")

  def events(store, order_id),
    do:
      Repo.all(
        from e in NativeOrderEvent,
          where: e.store_profile_id == ^store.id and e.order_summary_id == ^order_id,
          order_by: [asc: e.order_version]
      )

  def transition(store, id, action, attrs, expected_version, actor) do
    Repo.transaction(fn ->
      order =
        Repo.one!(
          from o in OrderSummary,
            where:
              o.id == ^id and o.store_profile_id == ^store.id and o.order_channel == "whatsapp",
            lock: "FOR UPDATE"
        )

      if order.lock_version != expected_version, do: Repo.rollback(:stale_order)
      unless is_binary(actor) and byte_size(actor) in 1..200, do: Repo.rollback(:invalid_actor)
      note = String.trim(Map.get(attrs, "note", ""))
      if byte_size(note) not in 1..2000, do: Repo.rollback(:evidence_required)
      changes = transition_changes(order, action, attrs)

      if changes == %{} do
        order
      else
        updated =
          order
          |> Ecto.Changeset.change(
            Map.merge(changes, %{lock_version: order.lock_version + 1, last_synced_at: now()})
          )
          |> Repo.update!()

        audit!(updated, actor, action, %{
          "note" => note,
          "before" => state(order),
          "after" => state(updated),
          "tracking_number" => Map.get(attrs, "tracking_number")
        })

        if action == "payment.received" && updated.opportunity_id do
          from(o in Opportunity,
            where:
              o.id == ^updated.opportunity_id and o.store_profile_id == ^store.id and
                o.customer_id == ^updated.customer_id
          )
          |> Repo.update_all(set: [stage: "won", updated_at: now()])
        end

        updated
      end
    end)
    |> notify(store)
  end

  defp transition_changes(order, "payment.received", _) do
    cond do
      order.financial_status == "paid" ->
        %{}

      order.status == "cancelled" or order.financial_status == "refunded" ->
        Repo.rollback(:invalid_transition)

      true ->
        %{financial_status: "paid", paid_at: now()}
    end
  end

  defp transition_changes(order, "payment.refunded", _) do
    cond do
      order.financial_status == "refunded" -> %{}
      order.financial_status != "paid" -> Repo.rollback(:invalid_transition)
      true -> %{financial_status: "refunded", refunded_total: order.total}
    end
  end

  defp transition_changes(order, "order.cancelled", _) do
    cond do
      order.status == "cancelled" ->
        %{}

      order.fulfillment_status not in ["unfulfilled", "returned"] ->
        Repo.rollback(:invalid_transition)

      true ->
        %{status: "cancelled", cancelled_at: now()}
    end
  end

  defp transition_changes(order, "shipment.shipped", attrs) do
    tracking = String.trim(Map.get(attrs, "tracking_number", ""))

    cond do
      order.fulfillment_status == "shipped" ->
        %{}

      order.status == "cancelled" or order.fulfillment_status != "unfulfilled" ->
        Repo.rollback(:invalid_transition)

      tracking == "" or byte_size(tracking) > 200 ->
        Repo.rollback(:tracking_required)

      true ->
        %{
          fulfillment_status: "shipped",
          snapshot: Map.put(order.snapshot, "tracking_number", tracking)
        }
    end
  end

  defp transition_changes(order, "shipment.delivered", _) do
    cond do
      order.fulfillment_status == "delivered" -> %{}
      order.fulfillment_status != "shipped" -> Repo.rollback(:invalid_transition)
      true -> %{fulfillment_status: "delivered"}
    end
  end

  defp transition_changes(order, "shipment.returned", _) do
    cond do
      order.fulfillment_status == "returned" ->
        %{}

      order.fulfillment_status not in ["shipped", "delivered"] ->
        Repo.rollback(:invalid_transition)

      true ->
        %{fulfillment_status: "returned"}
    end
  end

  defp transition_changes(_, _, _), do: Repo.rollback(:invalid_transition)

  defp state(order), do: Map.take(order, [:status, :financial_status, :fulfillment_status])

  defp audit!(order, actor, kind, evidence),
    do:
      Repo.insert!(%NativeOrderEvent{
        store_profile_id: order.store_profile_id,
        order_summary_id: order.id,
        order_version: order.lock_version,
        actor: actor,
        kind: kind,
        evidence: evidence
      })

  defp notify({:ok, order} = result, store) do
    Conversations.notify_changed(store.id, order.conversation_id)
    result
  end

  defp notify(result, _), do: result
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
