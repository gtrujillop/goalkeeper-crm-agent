defmodule StoreCRM.ConversationEngineE2ETest do
  use StoreCRM.DataCase, async: true

  alias StoreCRM.Agent.{AgentRun, Engine, ToolCall}
  alias StoreCRM.Conversations
  alias StoreCRM.Conversations.{Conversation, Handoff, Message}
  alias StoreCRM.Customers.{Customer, Identity}
  alias StoreCRM.Stores

  setup do
    {:ok, store} =
      Stores.create_profile(
        Map.put(Stores.colombia_attrs(), :slug, "colombia-#{System.unique_integer([:positive])}")
      )

    %{store: store}
  end

  test "normal answer persists the full Colombian store context and ordered outbound intent", %{
    store: store
  } do
    assert {:ok, result} =
             Engine.process_inbound(store, inbound("normal-1", "Hola, busco guantes"))

    assert result.customer.store_profile_id == store.id
    assert result.conversation.locale == "es-CO"
    assert result.outbound_message.direction == "outbound"
    assert {:ok, %{store_profile_id: store_id}} = result.outbound_intent
    assert store_id == store.id

    run = Repo.get!(AgentRun, result.agent_run.id)

    assert run.context == %{
             "currency" => "COP",
             "locale" => "es-CO",
             "market" => "CO",
             "phone_region" => "CO",
             "store_profile_id" => store.id,
             "timezone" => "America/Bogota"
           }

    assert run.prompt_version == "sales-assistant-v1"
    assert run.provider == "StoreCRM.AI.FakeProvider"
    assert run.model == "deterministic-local"
    assert run.outcome == "completed"
    assert Decimal.positive?(run.estimated_cost)

    assert [
             %Message{direction: "inbound", position: 1},
             %Message{direction: "outbound", position: 2}
           ] = Conversations.list_messages(store, result.conversation.id)

    assert Repo.aggregate(from(c in Customer, where: c.store_profile_id == ^store.id), :count) ==
             1

    assert Repo.get_by!(Identity, store_profile_id: store.id).normalized_value == "+573001234567"
  end

  test "tool-backed answer records validated calls and returns store currency", %{store: store} do
    assert {:ok, result} =
             Engine.process_inbound(
               store,
               inbound("tool-1", "¿Qué guantes sirven para cancha sintética?"),
               scenario: :tool
             )

    assert result.outbound_message.content =~ "COP"

    assert %ToolCall{
             name: "search_products",
             status: "succeeded",
             result: %{"products" => [product]}
           } = Repo.get_by!(ToolCall, agent_run_id: result.agent_run.id)

    assert product["currency"] == "COP"
  end

  test "duplicate provider message is processed once", %{store: store} do
    attrs = inbound("duplicate-1", "Necesito talla 9")
    assert {:ok, first} = Engine.process_inbound(store, attrs)
    assert {:ok, %{duplicate?: true}} = Engine.process_inbound(store, attrs)
    assert Repo.aggregate(from(m in Message, where: m.store_profile_id == ^store.id), :count) == 2

    assert Repo.aggregate(
             from(r in AgentRun, where: r.input_message_id == ^first.message.id),
             :count
           ) == 1
  end

  test "provider failure requests human takeover", %{store: store} do
    assert {:ok, result} =
             Engine.process_inbound(store, inbound("failure-1", "¿Tienen existencias?"),
               scenario: :provider_failure
             )

    assert result.conversation.state == "waiting_for_human"
    assert result.agent_run.outcome == "escalated"
    assert Repo.get_by!(Handoff, agent_run_id: result.agent_run.id).reason == "provider_failure"
  end

  test "bounded loop terminates after configured tool limit", %{store: store} do
    assert {:ok, result} =
             Engine.process_inbound(store, inbound("loop-1", "Busca opciones"), scenario: :loop)

    assert result.agent_run.outcome == "escalated"
    assert Repo.get_by!(Handoff, agent_run_id: result.agent_run.id).reason == "tool_limit"

    assert Repo.aggregate(
             from(t in ToolCall, where: t.agent_run_id == ^result.agent_run.id),
             :count
           ) == 3
  end

  test "token budget stops an oversized response", %{store: store} do
    assert {:ok, result} =
             Engine.process_inbound(store, inbound("tokens-1", "Cuéntame todo"),
               scenario: :token_limit
             )

    assert Repo.get_by!(Handoff, agent_run_id: result.agent_run.id).reason == "token_limit"
  end

  test "low confidence and disallowed actions escalate", %{store: store} do
    assert {:ok, low} =
             Engine.process_inbound(store, inbound("low-1", "¿Seguro?"),
               scenario: :low_confidence
             )

    assert Repo.get_by!(Handoff, agent_run_id: low.agent_run.id).reason == "low_confidence"

    assert {:ok, denied} =
             Engine.process_inbound(
               store,
               %{inbound("denied-1", "Hazme un reembolso") | phone: "+34600123456"},
               scenario: :disallowed
             )

    assert Repo.get_by!(Handoff, agent_run_id: denied.agent_run.id).reason == "disallowed_tool"

    assert Repo.get_by!(Identity, customer_id: denied.customer.id).normalized_value ==
             "+34600123456"
  end

  test "a human-owned conversation suppresses automated replies", %{store: store} do
    assert {:ok, first} = Engine.process_inbound(store, inbound("owned-1", "Necesito ayuda"))
    first.conversation |> Conversation.changeset(%{state: "human_owned"}) |> Repo.update!()

    assert {:ok, second} =
             Engine.process_inbound(store, %{inbound("owned-2", "¿Hola?") | phone: "3001234567"})

    assert second.conversation.state == "human_owned"
    refute second[:outbound_message]
  end

  defp inbound(id, content),
    do: %{
      source: "whatsapp",
      provider_message_id: id,
      phone: "3001234567",
      content: content,
      raw_payload: %{"id" => id}
    }
end
