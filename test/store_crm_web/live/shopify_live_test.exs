defmodule StoreCRMWeb.ShopifyLiveTest do
  use StoreCRMWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias StoreCRM.Commerce.CommerceSession
  alias StoreCRM.Stores

  setup do
    previous = Application.get_env(:store_crm, :catalogue_adapter)
    Application.put_env(:store_crm, :catalogue_adapter, StoreCRM.CatalogueFixture)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:store_crm, :catalogue_adapter, previous),
        else: Application.delete_env(:store_crm, :catalogue_adapter)
    end)

    case StoreCRM.Repo.get_by(StoreCRM.Stores.StoreProfile, slug: "colombia") do
      nil -> {:ok, _store} = Stores.create_profile(Stores.colombia_attrs())
      _store -> :ok
    end

    :ok
  end

  test "operator searches catalogue and creates a correlated cart", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/shopify")
    assert has_element?(view, "#shopify-workspace")
    assert has_element?(view, "#catalogue-search-form")

    view
    |> form("#catalogue-search-form", catalogue: %{query: "guantes"})
    |> render_submit()

    assert has_element?(view, "#catalogue-products article")
    assert has_element?(view, "#create-cart-available")

    view |> element("#create-cart-available") |> render_click()

    assert has_element?(view, "#cart-result")
    assert has_element?(view, "#open-test-checkout[href='https://shop.test/cart/c/test']")
    assert StoreCRM.Repo.aggregate(CommerceSession, :count) == 1
  end

  test "empty search stays safe and shows no products", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/shopify")

    view
    |> form("#catalogue-search-form", catalogue: %{query: " "})
    |> render_submit()

    refute has_element?(view, "#catalogue-products article")
    assert has_element?(view, "#catalogue-search-error")
  end
end
