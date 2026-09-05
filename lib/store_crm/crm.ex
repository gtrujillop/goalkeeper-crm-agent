defmodule StoreCRM.CRM do
  import Ecto.Query
  alias StoreCRM.Repo
  alias StoreCRM.Customers.{Customer, Identity}
  alias StoreCRM.Conversations.{Conversation, Handoff, Message}
  alias StoreCRM.CRM.{FollowUpTask, Note, Opportunity, OrderSummary}

  def inbox(store, query \\ "") do
    pattern = "%#{String.trim(query)}%"

    from(c in Conversation,
      join: customer in Customer,
      on: customer.id == c.customer_id,
      left_join: identity in Identity,
      on: identity.customer_id == customer.id and identity.store_profile_id == ^store.id,
      left_join: handoff in Handoff,
      on: handoff.conversation_id == c.id and handoff.status == "requested",
      where: c.store_profile_id == ^store.id,
      where:
        ^query == "" or ilike(coalesce(customer.name, ""), ^pattern) or
          ilike(coalesce(customer.email, ""), ^pattern) or
          ilike(identity.normalized_value, ^pattern),
      order_by: [
        desc:
          fragment(
            "CASE WHEN ? IS NOT NULL THEN 3 WHEN ? = 'human_owned' THEN 2 WHEN ? = 'waiting_for_human' THEN 1 ELSE 0 END",
            handoff.id,
            c.state,
            c.state
          ),
        desc: customer.last_interaction_at
      ],
      distinct: c.id,
      preload: [customer: customer]
    )
    |> Repo.all()
    |> Enum.map(&Map.put(&1, :attention_reason, attention_reason(&1)))
  end

  def workspace(store, conversation_id) do
    conversation =
      Repo.get_by!(Conversation, id: conversation_id, store_profile_id: store.id)
      |> Repo.preload(:customer)

    customer = conversation.customer

    %{
      conversation: conversation,
      customer: customer,
      identity:
        Repo.one(
          from i in Identity,
            where: i.customer_id == ^customer.id and i.store_profile_id == ^store.id,
            limit: 1
        ),
      messages:
        Repo.all(
          from m in Message,
            where: m.conversation_id == ^conversation.id,
            order_by: [asc: m.position]
        ),
      notes:
        Repo.all(
          from n in Note, where: n.customer_id == ^customer.id, order_by: [desc: n.inserted_at]
        ),
      tasks:
        Repo.all(
          from t in FollowUpTask, where: t.customer_id == ^customer.id, order_by: [asc: t.due_at]
        ),
      opportunities:
        Repo.all(
          from o in Opportunity,
            where: o.customer_id == ^customer.id,
            order_by: [desc: o.inserted_at]
        ),
      orders:
        Repo.all(
          from o in OrderSummary,
            where: o.customer_id == ^customer.id,
            order_by: [desc: o.placed_at]
        )
    }
  end

  def update_profile(store, customer_id, attrs),
    do: scoped(Customer, store, customer_id) |> Customer.changeset(attrs) |> Repo.update()

  def add_note(store, conversation, attrs),
    do:
      %Note{
        store_profile_id: store.id,
        customer_id: conversation.customer_id,
        conversation_id: conversation.id
      }
      |> Note.changeset(attrs)
      |> Repo.insert()

  def add_task(store, conversation, attrs),
    do:
      %FollowUpTask{
        store_profile_id: store.id,
        customer_id: conversation.customer_id,
        conversation_id: conversation.id
      }
      |> FollowUpTask.changeset(attrs)
      |> Repo.insert()

  def add_opportunity(store, customer_id, attrs),
    do:
      %Opportunity{store_profile_id: store.id, customer_id: customer_id}
      |> Opportunity.changeset(Map.put(attrs, "currency", store.currency))
      |> Repo.insert()

  def complete_task(store, id),
    do:
      scoped(FollowUpTask, store, id)
      |> FollowUpTask.changeset(%{status: "done"})
      |> Repo.update()

  def assign(store, id, manager),
    do:
      scoped(Conversation, store, id)
      |> Conversation.changeset(%{assigned_to: manager})
      |> Repo.update()

  def set_automation(store, id, enabled),
    do:
      scoped(Conversation, store, id)
      |> Conversation.changeset(%{
        automation_enabled: enabled,
        state: if(enabled, do: "active", else: "human_owned")
      })
      |> Repo.update()

  def manager_reply(store, conversation_id, content, adapter \\ nil) do
    conversation = scoped(Conversation, store, conversation_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset =
      %Message{
        store_profile_id: store.id,
        customer_id: conversation.customer_id,
        conversation_id: conversation.id
      }
      |> Message.changeset(%{
        direction: "outbound",
        source: "manager",
        provider_message_id: "manager-#{Ecto.UUID.generate()}",
        content: String.trim(content),
        status: "pending",
        position: StoreCRM.Conversations.next_position(conversation.id),
        occurred_at: now
      })

    with {:ok, message} <- Repo.insert(changeset),
         {:ok, delivery} <-
           (adapter || Application.get_env(:store_crm, :whatsapp, [])[:adapter] ||
              StoreCRM.Messaging.Fake).deliver(message, %{
             store_profile_id: store.id,
             locale: conversation.locale
           }) do
      message =
        message
        |> Message.changeset(%{provider_message_id: delivery.provider_message_id, status: "sent"})
        |> Repo.update!()

      {:ok, message}
    end
  end

  defp scoped(schema, store, id), do: Repo.get_by!(schema, id: id, store_profile_id: store.id)
  defp attention_reason(%{state: "waiting_for_human"}), do: "La IA solicitó ayuda"
  defp attention_reason(%{state: "human_owned"}), do: "Conversación en atención humana"
  defp attention_reason(%{state: "waiting_for_customer"}), do: "Esperando respuesta del cliente"
  defp attention_reason(_), do: "Conversación activa"
end
