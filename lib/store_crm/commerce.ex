defmodule StoreCRM.Commerce do
  alias StoreCRM.Commerce.CommerceSession
  alias StoreCRM.Repo
  import Ecto.Query

  def cart_context(context) do
    conversation =
      Repo.get_by!(StoreCRM.Conversations.Conversation,
        id: context.conversation_id,
        customer_id: context.customer_id,
        store_profile_id: context.store_profile_id
      )

    opportunities =
      Repo.all(
        from o in StoreCRM.CRM.Opportunity,
          where:
            o.store_profile_id == ^context.store_profile_id and
              o.customer_id == ^conversation.customer_id and o.stage not in ["won", "lost"],
          limit: 2
      )

    opportunity_id =
      case opportunities do
        [opportunity] -> opportunity.id
        _ -> nil
      end

    Map.merge(context, %{
      correlation_token:
        Phoenix.Token.sign(StoreCRMWeb.Endpoint, "commerce", Ecto.UUID.generate()),
      opportunity_id: opportunity_id
    })
  end

  def record_cart(context, cart) do
    context = if cart["correlation_token"], do: context, else: cart_context(context)

    %CommerceSession{
      correlation_token: cart["correlation_token"] || context.correlation_token,
      opportunity_id: cart["opportunity_id"] || Map.get(context, :opportunity_id),
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
