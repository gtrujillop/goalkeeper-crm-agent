defmodule StoreCRM.ShopifyCatalogueAndCartTest do
  use StoreCRM.DataCase, async: true

  alias StoreCRM.Agent.{Engine, ToolCall}
  alias StoreCRM.Commerce.CommerceSession
  alias StoreCRM.Conversations.Handoff
  alias StoreCRM.Stores
  alias StoreCRM.Catalogue.Shopify

  setup do
    {:ok, store} =
      Stores.create_profile(
        Map.put(Stores.colombia_attrs(), :slug, "shopify-#{System.unique_integer([:positive])}")
      )

    %{store: store}
  end

  test "fixture catalogue retains Shopify evidence, availability, currency and locale", %{
    store: store
  } do
    assert {:ok, result} =
             Engine.process_inbound(store, inbound("catalogue"),
               scenario: :tool,
               catalogue_adapter: StoreCRM.CatalogueFixture
             )

    call = Repo.get_by!(ToolCall, agent_run_id: result.agent_run.id)
    [product] = call.result["products"]
    assert product["url"] =~ "/products/"
    assert [%{"id" => "available"}] = product["purchasable_variants"]

    assert Enum.find(product["variants"], &(&1["id"] == "available"))["display_price"] ==
             "$189.900 COP"
  end

  test "cart is correlated to store, customer and conversation", %{store: store} do
    assert {:ok, result} =
             Engine.process_inbound(store, inbound("cart"),
               scenario: :cart,
               catalogue_adapter: StoreCRM.CatalogueFixture
             )

    session = Repo.get_by!(CommerceSession, conversation_id: result.conversation.id)
    assert session.customer_id == result.customer.id
    assert session.store_profile_id == store.id
    assert session.currency == "COP"
    assert session.checkout_url == "https://shop.test/cart/c/test"
  end

  test "Shopify failures safely escalate", %{store: store} do
    assert {:ok, result} =
             Engine.process_inbound(store, inbound("failure"),
               scenario: :tool,
               catalogue_adapter: StoreCRM.FailingCatalogue
             )

    assert result.conversation.state == "waiting_for_human"

    assert Repo.get_by!(Handoff, agent_run_id: result.agent_run.id).reason ==
             "commerce_provider_failure"
  end

  test "Shopify response fixture excludes unavailable variants from purchasable results" do
    fixture = %{
      "products" => %{
        "nodes" => [
          %{
            "id" => "product-1",
            "title" => "Guante",
            "handle" => "guante",
            "onlineStoreUrl" => "https://shop.test/products/guante",
            "variants" => %{
              "nodes" => [
                %{
                  "id" => "in-stock",
                  "title" => "9",
                  "availableForSale" => true,
                  "quantityAvailable" => 2,
                  "price" => %{"amount" => "189900.00", "currencyCode" => "COP"}
                },
                %{
                  "id" => "sold-out",
                  "title" => "10",
                  "availableForSale" => true,
                  "quantityAvailable" => 0,
                  "price" => %{"amount" => "179900.00", "currencyCode" => "COP"}
                }
              ]
            }
          }
        ]
      }
    }

    assert {:ok, %{"products" => [product]}} =
             Shopify.normalize_response("search_products", fixture, %{locale: "es-CO"})

    assert [%{"id" => "in-stock", "display_price" => "$189.900 COP"}] =
             product["purchasable_variants"]

    refute Enum.find(product["purchasable_variants"], &(&1["id"] == "sold-out"))
  end

  defp inbound(id),
    do: %{
      source: "whatsapp",
      provider_message_id: id,
      phone: "3001234567",
      content: "Necesito guantes",
      raw_payload: %{}
    }
end
