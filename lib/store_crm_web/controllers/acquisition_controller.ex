defmodule StoreCRMWeb.AcquisitionController do
  use StoreCRMWeb, :controller

  def redirect_to_whatsapp(conn, %{"store" => slug} = params) do
    store = StoreCRM.Repo.get_by(StoreCRM.Stores.StoreProfile, slug: slug)
    number = store && store.agent_limits["acquisition_whatsapp_number"]

    if is_binary(number) and Regex.match?(~r/^\d{8,15}$/, number) do
      {_touch, token} = StoreCRM.Attribution.create_redirect(store, params)

      redirect(conn,
        external:
          "https://wa.me/#{number}?" <>
            URI.encode_query(%{"text" => "Hola, quiero información [gk:#{token}]"})
      )
    else
      send_resp(conn, 404, "redirect not configured")
    end
  end
end
