defmodule StoreCRM.OrdersAndAttributionTest do
  use StoreCRM.DataCase, async: false
  alias StoreCRM.{Stores, Conversations, Commerce, Attribution}
  alias StoreCRM.Commerce.{Orders, ShopifyEvent}
  alias StoreCRM.CRM.{OrderSummary, Opportunity, FollowUpTask}

  setup do
    start_supervised!({Oban, Application.fetch_env!(:store_crm, Oban)})

    {:ok, store} =
      Stores.create_profile(
        Map.merge(Stores.colombia_attrs(), %{
          slug: Ecto.UUID.generate(),
          shopify_shop_domain: "test.myshopify.com"
        })
      )

    %{store: store}
  end

  test "durable jobs, duplicate events and repeat processing do not duplicate orders or follow-up",
       %{store: store} do
    payload = order()
    {:ok, event} = Orders.accept(store, "event-1", "orders/paid", payload)
    assert Repo.aggregate(Oban.Job, :count) == 1
    {:ok, duplicate} = Orders.accept(store, "event-1", "orders/paid", payload)
    assert duplicate.id == event.id
    assert Repo.aggregate(ShopifyEvent, :count) == 1
    assert Repo.aggregate(Oban.Job, :count) == 1
    assert {:ok, saved} = Orders.process(store.id, event.id)
    assert {:ok, again} = Orders.process(store.id, event.id)
    assert again.id == saved.id
    assert Repo.aggregate(OrderSummary, :count) == 1
    assert saved.order_channel == "direct_shopify"
    assert saved.financial_status == "paid"
    assert saved.identity_evidence["source"] == "new_shopify_customer"
    assert %{first: nil, last: nil} = Attribution.evidence(saved)

    assert [%{source: "unknown", orders: 1}] =
             Attribution.revenue(Attribution.report(store), :first)

    assert {:ok, task} = Orders.start_follow_up(store, saved.id)
    assert {:ok, same_task} = Orders.start_follow_up(store, saved.id)
    assert task.id == same_task.id
    assert Repo.aggregate(FollowUpTask, :count) == 1
  end

  test "signed cart correlates the exact opportunity and converts only on payment", %{
    store: store
  } do
    {:ok, inbound} = Conversations.ingest(store, inbound("cart"))

    {:ok, opportunity} =
      StoreCRM.CRM.add_opportunity(store, inbound.customer.id, %{"title" => "Gloves"})

    {:ok, session} =
      Commerce.record_cart(
        %{
          store_profile_id: store.id,
          customer_id: inbound.customer.id,
          conversation_id: inbound.conversation.id
        },
        %{"id" => "cart1", "checkout_url" => "https://test/cart", "currency" => "COP"}
      )

    payload =
      Map.put(order(), "note_attributes", [
        %{"name" => "gk_correlation", "value" => session.correlation_token}
      ])

    saved =
      process(store, "created", "orders/create", Map.put(payload, "financial_status", "pending"))

    assert saved.opportunity_id == opportunity.id
    assert Repo.get!(Opportunity, opportunity.id).stage == "new"
    paid = process(store, "paid", "orders/paid", payload)
    assert paid.customer_id == inbound.customer.id
    assert paid.conversation_id == inbound.conversation.id
    assert paid.order_channel == "assisted_shopify"
    assert Repo.get!(Opportunity, opportunity.id).stage == "won"
  end

  test "conflicting email never silently merges a phone match or converts opportunity", %{
    store: store
  } do
    {:ok, inbound} = Conversations.ingest(store, inbound("conflict"))

    {:ok, _} =
      StoreCRM.CRM.update_profile(store, inbound.customer.id, %{
        email: "known@example.com",
        profile_confidence: "confirmed"
      })

    saved =
      process(
        store,
        "conflict",
        "orders/paid",
        Map.merge(order(), %{"phone" => "3001234567", "email" => "other@example.com"})
      )

    assert saved.reconciliation_required
    refute saved.customer_id == inbound.customer.id
    assert saved.identity_evidence["source"] == "conflicting_identity"
    assert {:error, :identity_review_required} = Orders.start_follow_up(store, saved.id)

    again =
      process(
        store,
        "conflict-update",
        "orders/updated",
        Map.put(order(), "email", "other@example.com")
      )

    assert again.reconciliation_required
  end

  test "out of order events retain payment, cancellation, fulfillment, and independent refunds",
       %{store: store} do
    refund = %{
      "id" => 991,
      "order_id" => 123,
      "created_at" => "2026-09-05T14:00:00Z",
      "transactions" => [%{"kind" => "refund", "status" => "success", "amount" => "10000"}]
    }

    {:ok, event} = Orders.accept(store, "refund", "refunds/create", refund)
    assert {:error, :awaiting_order_snapshot} = Orders.process(store.id, event.id)

    process(
      store,
      "fulfilled",
      "orders/fulfilled",
      Map.put(order(), "updated_at", "2026-09-05T13:00:00Z")
    )

    process(
      store,
      "cancelled",
      "orders/cancelled",
      Map.put(order(), "updated_at", "2026-09-05T14:00:00Z")
    )

    process(store, "paid", "orders/paid", order())

    saved =
      process(
        store,
        "old",
        "orders/create",
        Map.merge(order(), %{
          "updated_at" => "2026-09-05T10:00:00Z",
          "financial_status" => "pending"
        })
      )

    assert saved.financial_status == "partially_refunded"
    assert saved.status == "cancelled"
    assert saved.fulfillment_status == "fulfilled"
    assert Decimal.equal?(saved.refunded_total, "10000")
    same_refund = process(store, "refund-delivery-2", "refunds/create", refund)
    assert Decimal.equal?(same_refund.refunded_total, "10000")
    assert Repo.get!(ShopifyEvent, event.id).status == "processed"
  end

  test "payment and shipping paths stay independent", %{store: store} do
    for {gateway, path, id} <- [
          {"Bank Transfer", "bank_transfer", 1},
          {"Mercado Pago", "mercado_pago_shopify", 2},
          {"Cash on Delivery (COD)", "collect_on_delivery", 3}
        ] do
      payload =
        Map.merge(order(), %{
          "id" => id,
          "financial_status" => "pending",
          "payment_gateway_names" => [gateway],
          "shipping_lines" => [%{"title" => "TCC"}]
        })

      saved = process(store, "path-#{id}", "orders/fulfilled", payload)
      assert saved.payment_path == path
      assert saved.carrier == "TCC"
      assert saved.financial_status == "pending"
      assert saved.fulfillment_status == "fulfilled"
      assert is_nil(saved.paid_at)
    end
  end

  test "Meta and Google evidence resolves once and reports first and last before purchase", %{
    store: store
  } do
    {_touch, token} =
      Attribution.create_redirect(store, %{
        "utm_campaign" => "gloves",
        "gclid" => "click",
        "secret" => "discard"
      })

    {:ok, result} =
      Conversations.ingest(
        store,
        Map.merge(inbound("google"), %{
          content: "Hola [gk:#{token}]",
          occurred_at: ~U[2026-09-05 15:00:00Z]
        })
      )

    {:ok, _} =
      Conversations.ingest(
        store,
        Map.merge(inbound("meta"), %{
          occurred_at: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 1),
          raw_payload: %{
            "referral" => %{
              "source_type" => "ad",
              "source_id" => "instagram-ad",
              "source_url" => "https://instagram.com/p/example"
            }
          }
        })
      )

    placed_at = DateTime.add(DateTime.utc_now(), 60) |> DateTime.to_iso8601()

    payload =
      Map.merge(order(), %{
        "phone" => "3001234567",
        "created_at" => placed_at,
        "updated_at" => placed_at
      })

    saved = process(store, "attributed", "orders/paid", payload)
    assert saved.customer_id == result.customer.id
    evidence = Attribution.evidence(saved)
    assert evidence.first.source == "google"
    assert evidence.last.source == "meta"
    assert evidence.first.evidence["utm_campaign"] == "gloves"
    refute evidence.first.evidence["secret"]

    {:ok, _} =
      Conversations.ingest(
        store,
        Map.merge(inbound("replay"), %{phone: "3019999999", content: "[gk:#{token}]"})
      )

    assert Repo.get!(StoreCRM.Attribution.Touchpoint, evidence.first.id).customer_id ==
             result.customer.id
  end

  test "invalid, expired and foreign tokens cannot claim attribution", %{store: store} do
    {touch, token} = Attribution.create_redirect(store, %{})
    touch |> Ecto.Changeset.change(expires_at: ~U[2020-01-01 00:00:00Z]) |> Repo.update!()

    {:ok, _} =
      Conversations.ingest(store, Map.merge(inbound("expired"), %{content: "[gk:#{token}]"}))

    assert is_nil(Repo.get!(StoreCRM.Attribution.Touchpoint, touch.id).customer_id)
    {:ok, other} = Stores.create_profile(Map.put(Stores.colombia_attrs(), :slug, "other"))
    {foreign, foreign_token} = Attribution.create_redirect(other, %{})

    {:ok, _} =
      Conversations.ingest(
        store,
        Map.merge(inbound("foreign"), %{content: "[gk:#{foreign_token}]"})
      )

    assert is_nil(Repo.get!(StoreCRM.Attribution.Touchpoint, foreign.id).customer_id)

    {:ok, _} =
      Conversations.ingest(store, Map.merge(inbound("invalid"), %{content: "[gk:invalid]"}))

    assert Attribution.report(other) == []
  end

  test "store isolation excludes foreign cart tokens, customers, orders and evidence", %{
    store: store
  } do
    {:ok, other} =
      Stores.create_profile(
        Map.merge(Stores.colombia_attrs(), %{
          slug: "isolated",
          shopify_shop_domain: "other.myshopify.com"
        })
      )

    {:ok, inbound} = Conversations.ingest(other, inbound("other-cart"))

    {:ok, session} =
      Commerce.record_cart(
        %{
          store_profile_id: other.id,
          customer_id: inbound.customer.id,
          conversation_id: inbound.conversation.id
        },
        %{"id" => "other-cart", "checkout_url" => "https://other/cart", "currency" => "COP"}
      )

    saved =
      process(
        store,
        "foreign-cart",
        "orders/paid",
        Map.put(order(), "note_attributes", [
          %{"name" => "gk_correlation", "value" => session.correlation_token}
        ])
      )

    assert saved.reconciliation_required
    refute saved.customer_id == inbound.customer.id
    assert Attribution.report(other) == []
    assert Orders.customer_totals(other, saved.customer_id) == []
    assert_raise Ecto.NoResultsError, fn -> Orders.start_follow_up(other, saved.id) end
  end

  test "customer totals account for refunds without double counting events", %{store: store} do
    saved = process(store, "totals-paid", "orders/paid", order())
    process(store, "totals-repeat", "orders/paid", order())

    process(store, "totals-refund", "refunds/create", %{
      "id" => 9,
      "order_id" => 123,
      "created_at" => "2026-09-05T14:00:00Z",
      "transactions" => [%{"kind" => "refund", "status" => "success", "amount" => "20000"}]
    })

    assert [%{order_count: 1, currency: "COP", lifetime_value: value}] =
             Orders.customer_totals(store, saved.customer_id)

    assert Decimal.equal?(value, "100000")
  end

  test "invalid payloads are rejected before enqueueing", %{store: store} do
    assert {:error, :invalid_event} = Orders.accept(store, "id", "products/create", order())
    assert {:error, :invalid_event} = Orders.accept(store, nil, "orders/paid", order())
    assert {:error, :invalid_event} = Orders.accept(store, "id", "orders/paid", %{})
    assert Repo.aggregate(ShopifyEvent, :count) == 0
  end

  defp process(store, id, topic, payload) do
    {:ok, event} = Orders.accept(store, id, topic, payload)
    {:ok, saved} = Orders.process(store.id, event.id)
    saved
  end

  defp order do
    %{
      "id" => 123,
      "name" => "#123",
      "created_at" => "2026-09-05T11:00:00Z",
      "updated_at" => "2026-09-05T12:00:00Z",
      "total_price" => "120000.00",
      "currency" => "COP",
      "financial_status" => "paid",
      "customer" => %{"id" => 55},
      "line_items" => [%{"title" => "Gloves", "quantity" => 1, "price" => "120000"}]
    }
  end

  defp inbound(id),
    do: %{
      source: "whatsapp",
      provider_message_id: id,
      phone: "3001234567",
      content: "Hola",
      raw_payload: %{}
    }
end
