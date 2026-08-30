defmodule StoreCRMWeb.WhatsAppWebhookControllerTest do
  use StoreCRMWeb.ConnCase, async: false
  use Oban.Testing, repo: StoreCRM.Repo

  alias StoreCRM.Messaging.{ProcessWebhookWorker, WebhookEvent}
  alias StoreCRM.{Messaging, Repo, Stores}

  setup do
    start_supervised!({Oban, Application.fetch_env!(:store_crm, Oban)})
    previous = Application.get_env(:store_crm, :whatsapp)

    Application.put_env(:store_crm, :whatsapp,
      adapter: StoreCRM.Messaging.Fake,
      verify_token: "verify-me",
      app_secret: "app-secret"
    )

    on_exit(fn -> Application.put_env(:store_crm, :whatsapp, previous) end)

    {:ok, store} =
      Stores.create_profile(
        Map.put(Stores.colombia_attrs(), :slug, "wa-#{System.unique_integer([:positive])}")
      )

    {:ok, account} =
      Messaging.create_account(store, %{
        phone_number_id: "phone-#{System.unique_integer([:positive])}",
        business_account_id: "business-1",
        locale_templates: %{"es-CO" => %{"welcome" => "bienvenida_co"}}
      })

    %{store: store, account: account}
  end

  test "verifies the subscription token", %{conn: conn} do
    conn =
      get(conn, "/webhooks/whatsapp", %{
        "hub.mode" => "subscribe",
        "hub.verify_token" => "verify-me",
        "hub.challenge" => "challenge-1"
      })

    assert response(conn, 200) == "challenge-1"
  end

  test "rejects invalid signatures before persistence", %{conn: conn, account: account} do
    conn = post_signed(conn, payload(account.phone_number_id, "bad-1"), "wrong-secret")
    assert response(conn, 401) == "invalid signature"
    refute Repo.get_by(WebhookEvent, external_id: "bad-1")
  end

  test "persists accepted events before enqueueing and deduplicates retries", %{
    conn: conn,
    account: account
  } do
    body = payload(account.phone_number_id, "wamid.inbound-1")
    assert post_signed(conn, body, "app-secret") |> response(200) == "EVENT_RECEIVED"

    assert %WebhookEvent{status: "accepted"} =
             event = Repo.get_by!(WebhookEvent, external_id: "wamid.inbound-1")

    assert_enqueued(worker: ProcessWebhookWorker, args: %{"event_id" => event.id})

    assert post_signed(build_conn(), body, "app-secret") |> response(200) == "EVENT_RECEIVED"
    assert Repo.aggregate(WebhookEvent, :count) == 1
    assert perform_job(ProcessWebhookWorker, %{"event_id" => event.id}) == :ok
    assert Repo.reload!(event).status == "processed"
  end

  test "rejects unsupported payloads safely", %{conn: conn} do
    assert post_signed(conn, %{"object" => "not-whatsapp"}, "app-secret") |> response(422) ==
             "unsupported payload"
  end

  defp post_signed(conn, body, secret) do
    encoded = Jason.encode!(body)
    signature = :crypto.mac(:hmac, :sha256, secret, encoded) |> Base.encode16(case: :lower)

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-hub-signature-256", "sha256=#{signature}")
    |> post("/webhooks/whatsapp", encoded)
  end

  defp payload(phone_number_id, id) do
    %{
      "object" => "whatsapp_business_account",
      "entry" => [
        %{
          "changes" => [
            %{
              "field" => "messages",
              "value" => %{
                "metadata" => %{"phone_number_id" => phone_number_id},
                "messages" => [
                  %{
                    "id" => id,
                    "from" => "573001234567",
                    "timestamp" => "1788026400",
                    "type" => "text",
                    "text" => %{"body" => "Hola"}
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end
end
