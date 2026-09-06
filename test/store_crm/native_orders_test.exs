defmodule StoreCRM.NativeOrdersTest do
  use StoreCRM.DataCase, async: true
  alias StoreCRM.{Stores, Conversations, Attribution}
  alias StoreCRM.Commerce.{NativeOrders, NativeOrderEvent, Orders}
  alias StoreCRM.CRM.{OrderSummary, Opportunity}

  setup do
    {:ok, store} =
      Stores.create_profile(Map.put(Stores.colombia_attrs(), :slug, Ecto.UUID.generate()))

    {:ok, conversation} =
      Conversations.ingest(store, %{
        source: "whatsapp",
        provider_message_id: Ecto.UUID.generate(),
        phone: "3001234567",
        content: "Quiero comprar",
        raw_payload: %{"referral" => %{"source_id" => "instagram-ad"}}
      })

    %{store: store, conversation: conversation.conversation, customer: conversation.customer}
  end

  test "native sale requires no Shopify and calculates trusted totals, snapshots, and attribution",
       %{store: store, conversation: conversation} do
    request = Ecto.UUID.generate()

    assert {:ok, order} =
             NativeOrders.create(
               store,
               conversation.id,
               request,
               Map.put(attrs(), "total", "1"),
               "Operator"
             )

    assert order.order_channel == "whatsapp"
    assert order.status == "confirmed"
    assert order.financial_status == "collect_on_delivery"
    assert is_nil(order.shopify_order_id)
    assert is_nil(order.shopify_admin_url)
    assert is_nil(order.paid_at)
    assert Decimal.equal?(order.total, "250000")
    assert order.snapshot["phone"] == "+573001234567"

    assert [%{"title" => "Guantes", "variant" => "Talla 9", "quantity" => 2}] =
             order.snapshot["line_items"]

    assert Attribution.evidence(order).first.source == "meta"

    assert [%{kind: "order.confirmed", actor: "Operator", order_version: 1}] =
             NativeOrders.events(store, order.id)

    assert {:ok, duplicate} =
             NativeOrders.create(store, conversation.id, request, attrs(), "Operator")

    assert duplicate.id == order.id
    assert Repo.aggregate(OrderSummary, :count) == 1
    assert Repo.aggregate(NativeOrderEvent, :count) == 1
    assert Attribution.revenue(Attribution.report(store), :first) == []
  end

  test "COD shipment and delivery never imply payment; receipt converts the explicit opportunity",
       %{store: store, conversation: conversation, customer: customer} do
    {:ok, opportunity} = StoreCRM.CRM.add_opportunity(store, customer.id, %{"title" => "Compra"})

    {:ok, order} =
      NativeOrders.create(
        store,
        conversation.id,
        Ecto.UUID.generate(),
        Map.put(attrs(), "opportunity_id", opportunity.id),
        "Operator"
      )

    assert Repo.reload!(opportunity).stage == "new"

    assert {:error, :tracking_required} =
             NativeOrders.transition(
               store,
               order.id,
               "shipment.shipped",
               %{"note" => "TCC"},
               1,
               "Operator"
             )

    {:ok, shipped} =
      NativeOrders.transition(
        store,
        order.id,
        "shipment.shipped",
        %{"note" => "Entregado a TCC", "tracking_number" => "TCC-123"},
        1,
        "Operator"
      )

    {:ok, delivered} =
      NativeOrders.transition(
        store,
        order.id,
        "shipment.delivered",
        %{"note" => "Entrega confirmada"},
        shipped.lock_version,
        "Operator"
      )

    assert delivered.financial_status == "collect_on_delivery"
    assert Repo.reload!(opportunity).stage == "new"

    assert {:ok, paid} =
             NativeOrders.transition(
               store,
               order.id,
               "payment.received",
               %{"note" => "Recaudo TCC abonado referencia 44"},
               delivered.lock_version,
               "Operator"
             )

    assert paid.financial_status == "paid"
    assert paid.fulfillment_status == "delivered"
    assert Repo.reload!(opportunity).stage == "won"
    assert [%{source: "meta", orders: 1}] = Attribution.revenue(Attribution.report(store), :first)

    assert {:ok, same} =
             NativeOrders.transition(
               store,
               order.id,
               "payment.received",
               %{"note" => "Misma confirmación"},
               paid.lock_version,
               "Operator"
             )

    assert same.lock_version == paid.lock_version
    assert Repo.aggregate(NativeOrderEvent, :count) == 4
    assert {:ok, _} = Orders.start_follow_up(store, order.id)
  end

  test "bank transfer evidence is required and a recorded refund leaves an audit trail", %{
    store: store,
    conversation: conversation
  } do
    {:ok, order} =
      NativeOrders.create(
        store,
        conversation.id,
        Ecto.UUID.generate(),
        Map.put(attrs(), "payment_path", "bank_transfer"),
        "Operator"
      )

    assert order.financial_status == "pending_transfer"

    assert {:error, :evidence_required} =
             NativeOrders.transition(
               store,
               order.id,
               "payment.received",
               %{"note" => " "},
               1,
               "Operator"
             )

    assert Repo.aggregate(NativeOrderEvent, :count) == 1

    {:ok, paid} =
      NativeOrders.transition(
        store,
        order.id,
        "payment.received",
        %{"note" => "Transferencia referencia 99"},
        1,
        "Operator"
      )

    assert {:error, :stale_order} =
             NativeOrders.transition(
               store,
               order.id,
               "order.cancelled",
               %{"note" => "Stale view"},
               1,
               "Operator"
             )

    {:ok, refunded} =
      NativeOrders.transition(
        store,
        order.id,
        "payment.refunded",
        %{"note" => "Devolución bancaria completada 100"},
        paid.lock_version,
        "Operator"
      )

    assert Decimal.equal?(refunded.refunded_total, order.total)
    assert [%{lifetime_value: value}] = Orders.customer_totals(store, order.customer_id)
    assert Decimal.equal?(value, 0)
    assert Enum.map(NativeOrders.events(store, order.id), & &1.order_version) == [1, 2, 3]
  end

  test "cancelled orders cannot be shipped or paid, and invalid item data is rejected", %{
    store: store,
    conversation: conversation
  } do
    invalid =
      Map.put(attrs(), "items", [
        %{"title" => "Guantes", "quantity" => -1, "unit_price" => "120000"}
      ])

    assert {:error, %Ecto.Changeset{}} =
             NativeOrders.create(
               store,
               conversation.id,
               Ecto.UUID.generate(),
               invalid,
               "Operator"
             )

    assert {:error, %Ecto.Changeset{}} =
             NativeOrders.create(
               store,
               conversation.id,
               Ecto.UUID.generate(),
               Map.put(attrs(), "items", []),
               "Operator"
             )

    assert Repo.aggregate(OrderSummary, :count) == 0

    {:ok, order} =
      NativeOrders.create(store, conversation.id, Ecto.UUID.generate(), attrs(), "Operator")

    {:ok, cancelled} =
      NativeOrders.transition(
        store,
        order.id,
        "order.cancelled",
        %{"note" => "Cliente desistió"},
        1,
        "Operator"
      )

    assert {:error, :invalid_transition} =
             NativeOrders.transition(
               store,
               order.id,
               "payment.received",
               %{"note" => "Wrong"},
               cancelled.lock_version,
               "Operator"
             )

    assert {:error, :invalid_transition} =
             NativeOrders.transition(
               store,
               order.id,
               "shipment.shipped",
               %{"note" => "Wrong", "tracking_number" => "1"},
               cancelled.lock_version,
               "Operator"
             )
  end

  test "native commands enforce store and opportunity ownership", %{
    store: store,
    conversation: conversation
  } do
    {:ok, other} = Stores.create_profile(Map.put(Stores.colombia_attrs(), :slug, "other-native"))

    {:ok, foreign} =
      Conversations.ingest(other, %{
        source: "whatsapp",
        provider_message_id: "foreign",
        phone: "3001234567",
        content: "Hola"
      })

    {:ok, opportunity} =
      StoreCRM.CRM.add_opportunity(other, foreign.customer.id, %{"title" => "Foreign"})

    assert {:error, :invalid_opportunity} =
             NativeOrders.create(
               store,
               conversation.id,
               Ecto.UUID.generate(),
               Map.put(attrs(), "opportunity_id", opportunity.id),
               "Operator"
             )

    assert_raise Ecto.NoResultsError, fn ->
      NativeOrders.create(
        store,
        foreign.conversation.id,
        Ecto.UUID.generate(),
        attrs(),
        "Operator"
      )
    end

    {:ok, order} =
      NativeOrders.create(store, conversation.id, Ecto.UUID.generate(), attrs(), "Operator")

    assert_raise Ecto.NoResultsError, fn -> NativeOrders.get!(other, order.id) end

    assert_raise Ecto.NoResultsError, fn ->
      NativeOrders.transition(
        other,
        order.id,
        "payment.received",
        %{"note" => "Foreign"},
        1,
        "Operator"
      )
    end

    assert NativeOrders.events(other, order.id) == []
    assert Repo.get!(Opportunity, opportunity.id).stage == "new"
  end

  defp attrs,
    do: %{
      "recipient" => "Laura",
      "phone" => "3001234567",
      "address" => "Calle 10 # 20-30",
      "city" => "Bogotá",
      "carrier" => "TCC",
      "payment_path" => "collect_on_delivery",
      "shipping_cost" => "10000",
      "items" => [
        %{"title" => "Guantes", "variant" => "Talla 9", "quantity" => 2, "unit_price" => "120000"}
      ]
    }
end
