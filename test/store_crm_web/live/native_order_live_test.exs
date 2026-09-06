defmodule StoreCRMWeb.NativeOrderLiveTest do
  use StoreCRMWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias StoreCRM.{Stores, Conversations, Repo}
  alias StoreCRM.Commerce.NativeOrders

  setup do
    store =
      Repo.get_by(StoreCRM.Stores.StoreProfile, slug: "colombia") ||
        elem(Stores.create_profile(Stores.colombia_attrs()), 1)

    {:ok, inbound} =
      Conversations.ingest(store, %{
        source: "whatsapp",
        provider_message_id: Ecto.UUID.generate(),
        phone: "3001234567",
        content: "Compro contraentrega"
      })

    %{store: store, conversation: inbound.conversation}
  end

  test "manager registers a multi-item native sale from a conversation", %{
    conn: conn,
    store: store,
    conversation: conversation
  } do
    {:ok, crm, _} = live(conn, ~p"/crm/conversations/#{conversation.id}")

    assert has_element?(
             crm,
             "#register-whatsapp-order[href='/crm/conversations/#{conversation.id}/orders/new']"
           )

    {:ok, view, _} = live(conn, ~p"/crm/conversations/#{conversation.id}/orders/new")
    assert has_element?(view, "#native-order-form")
    assert has_element?(view, "#order_phone[value='+573001234567']")
    view |> element("#add-native-item") |> render_click()
    assert has_element?(view, "#order_items_1_title")

    result =
      view
      |> form("#native-order-form",
        order: %{
          recipient: "Laura",
          phone: "3001234567",
          address: "Calle 10 # 20-30",
          city: "Bogotá",
          carrier: "TCC",
          payment_path: "collect_on_delivery",
          shipping_cost: "10000",
          items: %{
            "0" => %{title: "Guantes", variant: "Talla 9", quantity: "1", unit_price: "120000"},
            "1" => %{title: "Medias", quantity: "2", unit_price: "10000"}
          }
        }
      )
      |> render_submit()

    order = Repo.get_by!(StoreCRM.CRM.OrderSummary, conversation_id: conversation.id)
    assert Decimal.equal?(order.total, "150000")
    {:ok, detail, _} = follow_redirect(result, conn, ~p"/crm/orders/#{order.id}")
    assert has_element?(detail, "#native-payment-status", "contraentrega pendiente")
    assert has_element?(detail, "#native-order-history", "Pedido registrado")
    {:ok, orders_view, _} = live(conn, "/crm/orders")
    assert has_element?(orders_view, "#manage-native-#{order.id}")
    refute has_element?(orders_view, "#orders-#{order.id} a[href*='myshopify.com']")
    {:ok, admin, _} = live(conn, "/admin")
    assert has_element?(admin, "#admin-native-orders", "1")
    assert has_element?(admin, "#admin-native-cod-pending", "1")
    assert NativeOrders.get!(store, order.id).financial_status == "collect_on_delivery"
  end

  test "payment and shipment forms record distinct audited transitions", %{
    conn: conn,
    store: store,
    conversation: conversation
  } do
    {:ok, order} =
      NativeOrders.create(store, conversation.id, Ecto.UUID.generate(), attrs(), "Operator")

    {:ok, view, _} = live(conn, ~p"/crm/orders/#{order.id}")

    view
    |> form("#native-order-update-form",
      update: %{action: "shipment.shipped", note: "Guía creada", tracking_number: "TCC-9"}
    )
    |> render_submit()

    assert has_element?(view, "#native-delivery-status", "Enviado")
    assert has_element?(view, "#native-payment-status", "Transferencia pendiente")

    view
    |> form("#native-order-update-form",
      update: %{action: "payment.received", note: "Transferencia verificada 99"}
    )
    |> render_submit()

    assert has_element?(view, "#native-payment-status", "Pago recibido")
    assert has_element?(view, "#native-order-history", "Transferencia verificada 99")
    view |> element("#native-follow-up") |> render_click()

    assert Repo.get_by!(StoreCRM.CRM.FollowUpTask, order_summary_id: order.id).conversation_id ==
             conversation.id
  end

  test "stale operator forms cannot silently overwrite another update", %{
    conn: conn,
    store: store,
    conversation: conversation
  } do
    {:ok, order} =
      NativeOrders.create(store, conversation.id, Ecto.UUID.generate(), attrs(), "Operator")

    {:ok, view, _} = live(conn, ~p"/crm/orders/#{order.id}")

    {:ok, _} =
      NativeOrders.transition(
        store,
        order.id,
        "order.cancelled",
        %{"note" => "Cliente canceló"},
        1,
        "Other operator"
      )

    view
    |> form("#native-order-update-form",
      update: %{action: "payment.received", note: "Stale receipt"}
    )
    |> render_submit()

    assert has_element?(view, "#flash-error", "cambió en otra sesión")
    assert NativeOrders.get!(store, order.id).status == "cancelled"
    assert NativeOrders.get!(store, order.id).financial_status == "pending_transfer"
  end

  defp attrs,
    do: %{
      "recipient" => "Laura",
      "phone" => "3001234567",
      "address" => "Calle 10",
      "city" => "Bogotá",
      "payment_path" => "bank_transfer",
      "items" => [%{"title" => "Guantes", "quantity" => 1, "unit_price" => "120000"}]
    }
end
