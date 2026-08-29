defmodule StoreCRM.Commerce do
  alias StoreCRM.Commerce.CommerceSession
  alias StoreCRM.Repo

  def record_cart(context, cart) do
    %CommerceSession{
      store_profile_id: context.store_profile_id,
      customer_id: context.customer_id,
      conversation_id: context.conversation_id
    }
    |> CommerceSession.changeset(%{
      provider: "shopify",
      external_cart_id: cart["id"],
      checkout_url: cart["checkout_url"],
      currency: cart["currency"],
      raw_payload: cart
    })
    |> Repo.insert()
  end
end
