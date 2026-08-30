defmodule StoreCRM.WhatsAppMessagingTest do
  use StoreCRM.DataCase, async: true

  alias StoreCRM.Agent.Engine
  alias StoreCRM.Conversations.Message
  alias StoreCRM.Messaging.DeliveryEvent
  alias StoreCRM.{Messaging, Repo, Stores}

  setup do
    {:ok, store} =
      Stores.create_profile(
        Map.put(Stores.colombia_attrs(), :slug, "wa-domain-#{System.unique_integer([:positive])}")
      )

    %{store: store}
  end

  test "delivery statuses are idempotent, visible, and auditable", %{store: store} do
    {:ok, result} =
      Engine.process_inbound(store, %{
        source: "whatsapp",
        provider_message_id: "in-status",
        phone: "3001234567",
        content: "Hola"
      })

    message =
      result.outbound_message
      |> Message.changeset(%{provider_message_id: "wamid.out-1"})
      |> Repo.update!()

    {:ok, account} =
      Messaging.create_account(store, %{
        phone_number_id: "status-phone",
        business_account_id: "business"
      })

    status = %{"id" => "wamid.out-1", "status" => "delivered", "timestamp" => "1788026401"}

    event =
      %StoreCRM.Messaging.WebhookEvent{
        store_profile_id: store.id,
        whatsapp_account_id: account.id
      }
      |> StoreCRM.Messaging.WebhookEvent.changeset(%{
        external_id: "status-1",
        kind: "status",
        payload: status
      })
      |> Repo.insert!()

    assert :ok = Messaging.process_event(event)
    assert Repo.reload!(message).status == "delivered"

    assert %DeliveryEvent{status: "delivered", details: ^status} =
             Repo.get_by!(DeliveryEvent, message_id: message.id)
  end

  test "statuses for messages sent outside the CRM are acknowledged safely", %{store: store} do
    {:ok, account} =
      Messaging.create_account(store, %{
        phone_number_id: "unknown-status-phone",
        business_account_id: "business"
      })

    event =
      %StoreCRM.Messaging.WebhookEvent{
        store_profile_id: store.id,
        whatsapp_account_id: account.id
      }
      |> StoreCRM.Messaging.WebhookEvent.changeset(%{
        external_id: "unknown-status-1",
        kind: "status",
        payload: %{
          "id" => "wamid.sent-outside-crm",
          "status" => "read",
          "timestamp" => "1788026401"
        }
      })
      |> Repo.insert!()

    assert :ok = Messaging.process_event(event)
    assert Repo.reload!(event).status == "processed"
    refute Repo.get_by(DeliveryEvent, provider_event_id: "unknown-status-1")
  end

  test "human takeover immediately suppresses later automated delivery", %{store: store} do
    {:ok, first} =
      Engine.process_inbound(store, %{
        source: "whatsapp",
        provider_message_id: "takeover-1",
        phone: "3001234567",
        content: "Ayuda"
      })

    assert {:ok, conversation} = Messaging.take_over(store, first.conversation.id)
    assert conversation.state == "human_owned"

    assert {:ok, result} =
             Engine.process_inbound(store, %{
               source: "whatsapp",
               provider_message_id: "takeover-2",
               phone: "3001234567",
               content: "¿Hola?"
             })

    assert result.automation_suppressed?
    refute result[:outbound_message]
  end
end
