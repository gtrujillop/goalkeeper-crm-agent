defmodule StoreCRM.Messaging.WhatsApp do
  @behaviour StoreCRM.Messaging.Adapter
  alias StoreCRM.Conversations.Message
  alias StoreCRM.Messaging.{DeliveryEvent, WhatsAppAccount}
  alias StoreCRM.Repo

  @impl true
  def deliver(message, context) do
    config = Application.fetch_env!(:store_crm, :whatsapp)

    account =
      Repo.get_by!(WhatsAppAccount, store_profile_id: context.store_profile_id, active: true)

    identity =
      Repo.get_by!(StoreCRM.Customers.Identity,
        customer_id: message.customer_id,
        provider: "whatsapp"
      )

    url =
      "https://graph.facebook.com/#{config[:graph_api_version]}/#{account.phone_number_id}/messages"

    body = %{
      messaging_product: "whatsapp",
      to: identity.external_id,
      type: "text",
      text: %{body: message.content}
    }

    case Req.post(url,
           json: body,
           auth: {:bearer, config[:access_token]},
           retry: :transient,
           max_retries: 3
         ) do
      {:ok, %{status: status, body: %{"messages" => [%{"id" => provider_id} | _]}}}
      when status in 200..299 ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        message
        |> Message.changeset(%{provider_message_id: provider_id, status: "sent"})
        |> Repo.update!()

        %DeliveryEvent{store_profile_id: context.store_profile_id, message_id: message.id}
        |> DeliveryEvent.changeset(%{
          status: "sent",
          provider_event_id: "send:#{provider_id}",
          occurred_at: now
        })
        |> Repo.insert!()

        {:ok, %{provider_message_id: provider_id, store_profile_id: context.store_profile_id}}

      {:ok, response} ->
        delivery_failed(message, context, {:whatsapp_http_error, response.status})

      {:error, reason} ->
        delivery_failed(message, context, reason)
    end
  end

  def deliver_template(to, template_key, parameters, context) do
    config = Application.fetch_env!(:store_crm, :whatsapp)

    account =
      Repo.get_by!(WhatsAppAccount, store_profile_id: context.store_profile_id, active: true)

    template =
      get_in(account.locale_templates, [context.locale, template_key]) ||
        raise ArgumentError, "template is not configured for locale"

    url =
      "https://graph.facebook.com/#{config[:graph_api_version]}/#{account.phone_number_id}/messages"

    body = %{
      messaging_product: "whatsapp",
      to: to,
      type: "template",
      template: %{
        name: template,
        language: %{code: context.locale},
        components: parameters
      }
    }

    Req.post(url,
      json: body,
      auth: {:bearer, config[:access_token]},
      retry: :transient,
      max_retries: 3
    )
  end

  defp delivery_failed(message, context, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    message |> Message.changeset(%{status: "failed"}) |> Repo.update!()

    %DeliveryEvent{store_profile_id: context.store_profile_id, message_id: message.id}
    |> DeliveryEvent.changeset(%{
      status: "failed",
      provider_event_id: "failure:#{Ecto.UUID.generate()}",
      occurred_at: now,
      details: %{"reason" => inspect(reason)}
    })
    |> Repo.insert!()

    {:error, reason}
  end
end
