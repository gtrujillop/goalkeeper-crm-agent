defmodule StoreCRMWeb.OrdersLiveTest do
  use StoreCRMWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias StoreCRM.{Repo, Stores}
  alias StoreCRM.Commerce.Orders

  setup do
    start_supervised!({Oban, Application.fetch_env!(:store_crm, Oban)})

    store =
      Repo.get_by(StoreCRM.Stores.StoreProfile, slug: "colombia") ||
        elem(Stores.create_profile(Stores.colombia_attrs()), 1)

    {:ok, store} =
      Stores.update_profile(store, %{
        shopify_shop_domain: "orders.myshopify.com",
        agent_limits: %{"acquisition_whatsapp_number" => "573001234567"}
      })

    %{store: store}
  end

  test "direct purchases are visible with evidence and usable follow-up actions", %{
    conn: conn,
    store: store
  } do
    {:ok, event} =
      Orders.accept(store, "direct", "orders/paid", %{
        "id" => 1,
        "created_at" => "2026-09-05T10:00:00Z",
        "total_price" => "150000",
        "currency" => "COP"
      })

    {:ok, order} = Orders.process(store.id, event.id)
    {:ok, view, _} = live(conn, "/crm/orders")
    assert has_element?(view, "#orders-workspace")
    assert has_element?(view, "#orders-#{order.id} details")
    assert has_element?(view, "a[href='https://orders.myshopify.com/admin/orders/1']")
    view |> element("#last-touch") |> render_click()
    assert has_element?(view, "#last-touch[aria-pressed=true]")
    view |> element("#follow-up-#{order.id}") |> render_click()
    task = Repo.get_by!(StoreCRM.CRM.FollowUpTask, order_summary_id: order.id)
    assert has_element?(view, "#complete-#{task.id}")
    view |> element("#complete-#{task.id}") |> render_click()
    assert Repo.reload!(task).status == "done"
    refute has_element?(view, "#complete-#{task.id}")
  end

  test "redirect preserves only allowed evidence and uses a configured destination", %{
    conn: conn,
    store: store
  } do
    conn =
      get(conn, "/r/colombia/google", %{utm_campaign: "keepers", redirect: "https://evil.test"})

    assert redirected_to(conn, 302) =~ "https://wa.me/573001234567?"
    touch = Repo.get_by!(StoreCRM.Attribution.Touchpoint, store_profile_id: store.id)
    assert touch.evidence == %{"utm_campaign" => "keepers"}
  end
end
