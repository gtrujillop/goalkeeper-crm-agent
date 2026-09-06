defmodule StoreCRMWeb.ShopifyWebhookController do
  use StoreCRMWeb, :controller
  require Ecto.Query
  alias StoreCRM.Commerce.Orders

  def receive(conn, payload) do
    domain = header(conn, "x-shopify-shop-domain")
    secret = Application.get_env(:store_crm, :shopify_webhook_secret)

    with true <- is_binary(domain) and domain != "",
         true <-
           Orders.signature_valid?(
             conn.assigns[:raw_body] || "",
             header(conn, "x-shopify-hmac-sha256"),
             secret
           ),
         [store] <-
           StoreCRM.Repo.all(
             Ecto.Query.where(StoreCRM.Stores.StoreProfile, shopify_shop_domain: ^domain)
           ),
         {:ok, _} <-
           Orders.accept(
             store,
             header(conn, "x-shopify-event-id") || header(conn, "x-shopify-webhook-id"),
             header(conn, "x-shopify-topic"),
             payload
           ) do
      send_resp(conn, 200, "EVENT_RECEIVED")
    else
      false -> send_resp(conn, 401, "invalid signature")
      {:error, :invalid_event} -> send_resp(conn, 422, "invalid event")
      {:error, _} -> send_resp(conn, 503, "persistence failed")
      _ -> send_resp(conn, 404, "unknown or ambiguous shop")
    end
  end

  defp header(conn, name), do: conn |> get_req_header(name) |> List.first()
end
