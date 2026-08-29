defmodule StoreCRM.StoresTest do
  use StoreCRM.DataCase, async: true

  alias StoreCRM.Conversations.ProcessInboundWorker
  alias StoreCRM.Stores

  test "Colombia seed defines the initial market defaults" do
    attrs = Stores.colombia_attrs()
    assert attrs.market == "CO"
    assert attrs.default_locale == "es-CO"
    assert attrs.currency == "COP"
    assert attrs.timezone == "America/Bogota"
    assert attrs.phone_region == "CO"
  end

  test "background ingestion is created only with an explicit store profile" do
    {:ok, store} = Stores.create_profile(Map.put(Stores.colombia_attrs(), :slug, "worker-store"))

    job =
      ProcessInboundWorker.new_for_store(store, %{
        source: "whatsapp",
        provider_message_id: "job-1",
        phone: "3001234567",
        content: "Hola"
      })

    assert job.changes.args["store_profile_id"] == store.id

    assert {:discard, :store_profile_required} =
             ProcessInboundWorker.perform(%Oban.Job{args: %{}})
  end
end
