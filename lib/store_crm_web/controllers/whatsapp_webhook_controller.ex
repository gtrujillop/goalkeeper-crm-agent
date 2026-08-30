defmodule StoreCRMWeb.WhatsAppWebhookController do
  use StoreCRMWeb, :controller

  def verify(conn, %{
        "hub.mode" => "subscribe",
        "hub.verify_token" => token,
        "hub.challenge" => challenge
      }) do
    expected = Application.get_env(:store_crm, :whatsapp, [])[:verify_token]

    if secure_equal?(token, expected),
      do: send_resp(conn, 200, challenge),
      else: send_resp(conn, 403, "forbidden")
  end

  def verify(conn, _), do: send_resp(conn, 400, "invalid verification request")

  def receive(conn, payload) do
    config = Application.get_env(:store_crm, :whatsapp, [])
    signature = get_req_header(conn, "x-hub-signature-256") |> List.first()

    cond do
      not StoreCRM.Messaging.signature_valid?(
        conn.assigns[:raw_body] || "",
        signature,
        config[:app_secret]
      ) ->
        send_resp(conn, 401, "invalid signature")

      true ->
        case StoreCRM.Messaging.accept_webhook(payload) do
          {:ok, _} -> send_resp(conn, 200, "EVENT_RECEIVED")
          {:error, :unsupported_payload} -> send_resp(conn, 422, "unsupported payload")
          {:error, :unknown_phone_number} -> send_resp(conn, 404, "unknown account")
          {:error, _} -> send_resp(conn, 500, "webhook persistence failed")
        end
    end
  end

  defp secure_equal?(left, right) when is_binary(right) and byte_size(left) == byte_size(right),
    do: Plug.Crypto.secure_compare(left, right)

  defp secure_equal?(_, _), do: false
end
