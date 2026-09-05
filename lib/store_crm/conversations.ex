defmodule StoreCRM.Conversations do
  import Ecto.Query
  alias Ecto.Multi
  alias StoreCRM.Repo
  alias StoreCRM.Customers.{Customer, Identity, Phone}
  alias StoreCRM.Conversations.{Conversation, Message}

  def subscribe(store_profile_id),
    do: Phoenix.PubSub.subscribe(StoreCRM.PubSub, topic(store_profile_id))

  def notify_changed(store_profile_id, conversation_id),
    do:
      Phoenix.PubSub.broadcast(
        StoreCRM.PubSub,
        topic(store_profile_id),
        {:conversation_changed, conversation_id}
      )

  def ingest(store_profile, attrs) when not is_nil(store_profile.id) do
    with {:ok, phone} <- Phone.normalize(attrs.phone, store_profile.phone_region) do
      case Repo.get_by(Message,
             store_profile_id: store_profile.id,
             source: attrs.source,
             provider_message_id: attrs.provider_message_id
           ) do
        nil -> persist_inbound(store_profile, attrs, phone)
        message -> {:ok, %{duplicate?: true, message: message}}
      end
    end
  end

  def list_messages(store_profile, conversation_id) do
    from(m in Message,
      where: m.store_profile_id == ^store_profile.id and m.conversation_id == ^conversation_id,
      order_by: [asc: m.position]
    )
    |> Repo.all()
  end

  defp persist_inbound(store, attrs, phone) do
    now = Map.get(attrs, :occurred_at, DateTime.utc_now() |> DateTime.truncate(:second))

    identity =
      Repo.get_by(Identity,
        store_profile_id: store.id,
        provider: attrs.source,
        normalized_value: phone
      )

    Multi.new()
    |> customer_steps(store, identity, now, phone, attrs.source)
    |> Multi.run(:conversation, fn repo, %{customer: customer} ->
      active_conversation(repo, store, customer)
    end)
    |> Multi.run(:message, fn repo, %{customer: customer, conversation: conversation} ->
      %Message{
        store_profile_id: store.id,
        customer_id: customer.id,
        conversation_id: conversation.id
      }
      |> Message.changeset(%{
        direction: "inbound",
        source: attrs.source,
        provider_message_id: attrs.provider_message_id,
        content: attrs.content,
        status: "received",
        position: next_position(repo, conversation.id),
        occurred_at: now,
        raw_payload: Map.get(attrs, :raw_payload, %{})
      })
      |> repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, result} -> {:ok, Map.put(result, :duplicate?, false)}
      {:error, :message, changeset, _} -> duplicate_after_conflict(store, attrs, changeset)
      {:error, step, reason, _} -> {:error, {step, reason}}
    end
  end

  defp customer_steps(multi, store, nil, now, phone, source) do
    multi
    |> Multi.insert(
      :customer,
      %Customer{store_profile_id: store.id}
      |> Customer.changeset(%{first_interaction_at: now, last_interaction_at: now})
    )
    |> Multi.insert(:identity, fn %{customer: customer} ->
      %Identity{store_profile_id: store.id, customer_id: customer.id}
      |> Identity.changeset(%{provider: source, external_id: phone, normalized_value: phone})
    end)
  end

  defp customer_steps(multi, store, identity, now, _phone, _source) do
    customer = Repo.get_by!(Customer, id: identity.customer_id, store_profile_id: store.id)
    Multi.update(multi, :customer, Customer.changeset(customer, %{last_interaction_at: now}))
  end

  defp active_conversation(repo, store, customer) do
    states = ["active", "waiting_for_customer", "waiting_for_human", "human_owned"]

    query =
      from c in Conversation,
        where:
          c.store_profile_id == ^store.id and c.customer_id == ^customer.id and c.state in ^states,
        order_by: [desc: c.inserted_at],
        limit: 1

    case repo.one(query) do
      nil ->
        %Conversation{store_profile_id: store.id, customer_id: customer.id}
        |> Conversation.changeset(%{
          state: "active",
          locale: customer.preferred_locale || store.default_locale
        })
        |> repo.insert()

      conversation ->
        {:ok, conversation}
    end
  end

  defp duplicate_after_conflict(store, attrs, changeset) do
    if changeset.errors != [] do
      {:ok,
       %{
         duplicate?: true,
         message:
           Repo.get_by!(Message,
             store_profile_id: store.id,
             source: attrs.source,
             provider_message_id: attrs.provider_message_id
           )
       }}
    else
      {:error, {:message, changeset}}
    end
  end

  def next_position(repo \\ Repo, conversation_id) do
    (repo.one(
       from m in Message,
         where: m.conversation_id == ^conversation_id,
         select: max(m.position)
     ) || 0) + 1
  end

  defp topic(store_profile_id), do: "crm:store:#{store_profile_id}"
end
