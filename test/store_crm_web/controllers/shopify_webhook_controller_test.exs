defmodule StoreCRMWeb.ShopifyWebhookControllerTest do
  use StoreCRMWeb.ConnCase, async: false
  use Oban.Testing, repo: StoreCRM.Repo
  alias StoreCRM.{Repo, Stores}
  alias StoreCRM.Commerce.{ShopifyEvent, ProcessOrderWorker}

  setup do
    start_supervised!({Oban, Application.fetch_env!(:store_crm, Oban)})
    previous = Application.get_env(:store_crm, :shopify_webhook_secret)
    Application.put_env(:store_crm, :shopify_webhook_secret, "secret")
    on_exit(fn -> Application.put_env(:store_crm, :shopify_webhook_secret, previous) end)

    {:ok, store} =
      Stores.create_profile(
        Map.merge(Stores.colombia_attrs(), %{
          slug: "webhooks",
          shopify_shop_domain: "signed.myshopify.com"
        })
      )

    %{store: store}
  end

  test "authenticates raw bytes, routes store, and persists event and job once", %{
    conn: conn,
    store: store
  } do
    assert response(post_signed(conn), 200) == "EVENT_RECEIVED"
    assert response(post_signed(build_conn()), 200) == "EVENT_RECEIVED"
    assert Repo.aggregate(ShopifyEvent, :count) == 1
    event = Repo.one!(ShopifyEvent)
    assert event.store_profile_id == store.id

    assert_enqueued(
      worker: ProcessOrderWorker,
      args: %{event_id: event.id, store_profile_id: store.id}
    )

    assert perform_job(ProcessOrderWorker, %{event_id: event.id, store_profile_id: store.id}) ==
             :ok
  end

  test "rejects invalid signatures and unknown shops without persistence", %{conn: conn} do
    assert response(post_signed(conn, "wrong"), 401) == "invalid signature"

    assert response(post_signed(build_conn(), "secret", "unknown.myshopify.com"), 404) ==
             "unknown or ambiguous shop"

    assert Repo.aggregate(ShopifyEvent, :count) == 0
  end

  defp post_signed(conn, secret \\ "secret", domain \\ "signed.myshopify.com") do
    body =
      Jason.encode!(%{
        id: 22,
        created_at: "2026-09-05T10:00:00Z",
        total_price: "100",
        currency: "COP"
      })

    signature = :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode64()

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-shopify-hmac-sha256", signature)
    |> put_req_header("x-shopify-shop-domain", domain)
    |> put_req_header("x-shopify-topic", "orders/paid")
    |> put_req_header("x-shopify-event-id", "event-1")
    |> post("/webhooks/shopify", body)
  end
end
