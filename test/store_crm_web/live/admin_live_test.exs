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
end
