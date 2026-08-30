defmodule StoreCRMWeb.CRMLiveTest do
  use StoreCRMWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias StoreCRM.{Conversations, Repo, Stores}
  alias StoreCRM.CRM.OrderSummary
  alias StoreCRM.Conversations.{Conversation, Message}

  setup do
    previous = Application.get_env(:store_crm, :whatsapp)
    Application.put_env(:store_crm, :whatsapp, adapter: StoreCRM.Messaging.Fake)
    on_exit(fn -> Application.put_env(:store_crm, :whatsapp, previous) end)

    store =
      Repo.get_by(StoreCRM.Stores.StoreProfile, slug: "colombia") ||
        elem(Stores.create_profile(Stores.colombia_attrs()), 1)

    {:ok, first} =
      Conversations.ingest(store, %{
        source: "whatsapp",
        provider_message_id: "crm-#{Ecto.UUID.generate()}",
        phone: "3001234567",
        content: "Necesito ayuda con mi pedido"
      })

    {:ok, customer} =
      StoreCRM.CRM.update_profile(store, first.customer.id, %{
        name: "Laura Gómez",
        email: "laura@example.com",
        profile_confidence: "confirmed"
      })

    first.conversation |> Conversation.changeset(%{state: "waiting_for_human"}) |> Repo.update!()

    %OrderSummary{store_profile_id: store.id, customer_id: customer.id}
    |> OrderSummary.changeset(%{
      shopify_order_id: "gid://shopify/Order/55",
      order_name: "#1055",
      status: "Pagado",
      total: Decimal.new("350000"),
      currency: "COP",
      shopify_admin_url: "https://admin.shopify.com/store/test/orders/55",
      placed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()

    %{store: store, conversation: first.conversation}
  end

  test "manager searches, opens prioritized context, takes over and replies", %{
    conn: conn,
    conversation: conversation
  } do
    {:ok, view, _html} = live(conn, ~p"/crm")
    assert has_element?(view, "#crm-workspace")
    assert has_element?(view, "#conversation-inbox button")

    view |> form("#customer-search-form", search: %{query: "Laura"}) |> render_change()
    assert has_element?(view, "#conversation-inbox button")
    view |> element("#conversation-inbox button") |> render_click()
    assert_patch(view, ~p"/crm/conversations/#{conversation.id}")
    assert has_element?(view, "#conversation-detail")
    assert has_element?(view, "#order-summaries a[target='_blank']")

    view |> element("#assign-button") |> render_click()
    assert Repo.get!(Conversation, conversation.id).assigned_to == "Manager"

    view |> element("#takeover-button") |> render_click()
    assert Repo.get!(Conversation, conversation.id).automation_enabled == false

    view
    |> form("#manager-reply-form", reply: %{content: "Hola Laura, ya reviso tu pedido."})
    |> render_submit()

    assert has_element?(view, "#message-timeline article", "Hola Laura")
  end

  test "manager confirms profile and records next actions", %{
    conn: conn,
    conversation: conversation
  } do
    {:ok, view, _html} = live(conn, ~p"/crm/conversations/#{conversation.id}")

    view
    |> form("#customer-profile-form", profile: %{name: "Laura G.", email: "laura.g@example.com"})
    |> render_submit()

    view |> form("#note-form", note: %{body: "Prefiere talla 9"}) |> render_submit()
    view |> form("#task-form", task: %{title: "Confirmar guía de envío"}) |> render_submit()

    view
    |> form("#opportunity-form",
      opportunity: %{title: "Renovación de guantes", stage: "qualified"}
    )
    |> render_submit()

    assert has_element?(view, "#notes p", "Prefiere talla 9")
    assert has_element?(view, "#tasks button", "Confirmar guía")
    assert Repo.aggregate(StoreCRM.CRM.Opportunity, :count) == 1
  end

  test "search is store scoped and supports normalized phone", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/crm")
    view |> form("#customer-search-form", search: %{query: "+573001234567"}) |> render_change()
    assert has_element?(view, "#conversation-inbox button")

    view
    |> form("#customer-search-form", search: %{query: "nadie@example.com"})
    |> render_change()

    refute has_element?(view, "#conversation-inbox button")
    assert has_element?(view, "#inbox-empty")
  end

  test "open conversation refreshes when webhook processing publishes a change", %{
    conn: conn,
    store: store,
    conversation: conversation
  } do
    {:ok, view, _html} = live(conn, ~p"/crm/conversations/#{conversation.id}")

    %Message{
      store_profile_id: store.id,
      customer_id: conversation.customer_id,
      conversation_id: conversation.id
    }
    |> Message.changeset(%{
      direction: "inbound",
      source: "whatsapp",
      provider_message_id: "live-refresh-#{Ecto.UUID.generate()}",
      content: "Ya envié los datos",
      status: "received",
      position: Conversations.next_position(conversation.id),
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()

    Conversations.notify_changed(store.id, conversation.id)
    assert has_element?(view, "#message-timeline article", "Ya envié los datos")
  end
end
