defmodule StoreCRMWeb.AdminLiveTest do
  use StoreCRMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias StoreCRM.Messaging
  alias StoreCRM.Stores

  setup do
    store =
      StoreCRM.Repo.get_by(StoreCRM.Stores.StoreProfile, slug: "colombia") ||
        elem(Stores.create_profile(Stores.colombia_attrs()), 1)

    %{store: store}
  end

  test "admin creates and updates a store-scoped WhatsApp account", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "#admin-workspace")
    assert has_element?(view, "#credential-status")

    phone_number_id = "phone-#{System.unique_integer([:positive])}"

    view
    |> form("#whatsapp-account-form",
      whats_app_account: %{
        business_account_id: "waba-123",
        phone_number_id: phone_number_id,
        active: true
      }
    )
    |> render_submit()

    [account] =
      Enum.filter(Messaging.list_accounts(store), &(&1.phone_number_id == phone_number_id))

    assert account.business_account_id == "waba-123"
    assert has_element?(view, "#account-#{account.id}")

    view |> element("#account-#{account.id}") |> render_click()

    view
    |> form("#whatsapp-account-form",
      whats_app_account: %{
        business_account_id: "waba-123",
        phone_number_id: phone_number_id,
        active: false
      }
    )
    |> render_submit()

    refute Messaging.get_account!(store, account.id).active
  end

  test "admin updates operating store settings", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/admin")

    view
    |> form("#store-settings-form",
      store_profile: %{
        name: "Goalkeeper Colombia",
        default_locale: store.default_locale,
        timezone: store.timezone,
        currency: store.currency,
        phone_region: store.phone_region,
        shopify_shop_domain: "goalkeeper-colombia.myshopify.com"
      }
    )
    |> render_submit()

    updated = Stores.get_profile!(store.id)
    assert updated.name == "Goalkeeper Colombia"
    assert updated.shopify_shop_domain == "goalkeeper-colombia.myshopify.com"
  end

  test "admin configures order tracking and campaign destination without losing agent settings",
       %{conn: conn, store: store} do
    {:ok, view, _} = live(conn, ~p"/admin")
    assert has_element?(view, "#admin-orders-link[href='/crm/orders']")
    assert has_element?(view, "#order-integration-form")

    view
    |> form("#order-integration-form",
      integration_settings: %{
        shopify_shop_domain: "KEEPERS.myshopify.com",
        whatsapp_number: "+57 300 123 4567",
        bank_transfer: "Transferencia Bancolombia",
        mercado_pago_shopify: "Pasarela MP",
        collect_on_delivery: "Recaudo TCC"
      }
    )
    |> render_submit()

    updated = Stores.get_profile!(store.id)
    assert updated.shopify_shop_domain == "keepers.myshopify.com"
    assert updated.agent_limits["max_tool_calls"] == store.agent_limits["max_tool_calls"]
    assert updated.agent_limits["acquisition_whatsapp_number"] == "573001234567"

    assert updated.agent_limits["payment_paths"] == %{
             "transferencia bancolombia" => "bank_transfer",
             "pasarela mp" => "mercado_pago_shopify",
             "recaudo tcc" => "collect_on_delivery"
           }

    assert has_element?(view, "#google-tracking-link code", "/r/colombia/google")
    assert has_element?(view, "#shopify-webhook-url", "/webhooks/shopify")

    view
    |> form("#order-integration-form",
      integration_settings: %{whatsapp_number: "", bank_transfer: ""}
    )
    |> render_submit()

    cleared = Stores.get_profile!(store.id)
    assert is_nil(cleared.agent_limits["acquisition_whatsapp_number"])
    refute Map.has_key?(cleared.agent_limits["payment_paths"], "transferencia bancolombia")
    assert cleared.agent_limits["payment_paths"]["pasarela mp"] == "mercado_pago_shopify"
    refute has_element?(view, "#google-tracking-link code")
  end

  test "invalid settings and duplicate store domains cannot be saved", %{conn: conn, store: store} do
    {:ok, _} =
      Stores.create_profile(
        Map.merge(Stores.colombia_attrs(), %{
          slug: "other-settings",
          shopify_shop_domain: "taken.myshopify.com"
        })
      )

    {:ok, view, _} = live(conn, ~p"/admin")

    view
    |> form("#order-integration-form",
      integration_settings: %{
        shopify_shop_domain: "https://wrong.test/path",
        whatsapp_number: "abc"
      }
    )
    |> render_submit()

    assert has_element?(view, "#order-integration-form", "Usa el dominio")
    assert has_element?(view, "#order-integration-form", "Incluye el indicativo")

    view
    |> form("#order-integration-form",
      integration_settings: %{
        shopify_shop_domain: "taken.myshopify.com",
        whatsapp_number: "",
        bank_transfer: "Manual",
        collect_on_delivery: "manual"
      }
    )
    |> render_submit()

    assert has_element?(view, "#order-integration-form", "ya pertenece a otra tienda")
    assert has_element?(view, "#order-integration-form", "una sola categoría")
    assert Stores.get_profile!(store.id).shopify_shop_domain == store.shopify_shop_domain
  end

  test "monitor shows scoped event evidence, refreshes, and masks the signing secret", %{
    conn: conn,
    store: store
  } do
    previous = Application.get_env(:store_crm, :shopify_webhook_secret)
    Application.put_env(:store_crm, :shopify_webhook_secret, "private-signing-secret")
    on_exit(fn -> Application.put_env(:store_crm, :shopify_webhook_secret, previous) end)
    {:ok, other} = Stores.create_profile(Map.put(Stores.colombia_attrs(), :slug, "other-monitor"))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    local =
      StoreCRM.Repo.insert!(%StoreCRM.Commerce.ShopifyEvent{
        store_profile_id: store.id,
        external_id: "local-event",
        order_id: "1",
        topic: "refunds/create",
        status: "failed",
        error: ":awaiting_order_snapshot",
        payload: %{},
        occurred_at: now
      })

    foreign =
      StoreCRM.Repo.insert!(%StoreCRM.Commerce.ShopifyEvent{
        store_profile_id: other.id,
        external_id: "foreign-event",
        order_id: "2",
        topic: "orders/paid",
        status: "failed",
        payload: %{},
        occurred_at: now
      })

    {:ok, view, _} = live(conn, ~p"/admin")
    assert has_element?(view, "#shopify-secret-status[data-ready=true]")
    refute has_element?(view, "#order-integration", "private-signing-secret")
    assert has_element?(view, "#integration-failed", "1")
    assert has_element?(view, "#shopify_events-#{local.id}", "reembolso llegó antes")
    refute has_element?(view, "#shopify_events-#{foreign.id}")
    StoreCRM.Repo.update!(Ecto.Changeset.change(local, status: "processed", error: nil))
    view |> element("#refresh-order-integration") |> render_click()
    assert has_element?(view, "#integration-failed", "0")
    assert has_element?(view, "#integration-processed", "1")
    assert has_element?(view, "#shopify_events-#{local.id}", "Procesado")
  end
end
