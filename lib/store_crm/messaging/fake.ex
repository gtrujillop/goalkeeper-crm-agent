defmodule StoreCRM.Messaging.Fake do
  @behaviour StoreCRM.Messaging.Adapter
  def deliver(intent, context),
    do:
      {:ok,
       %{provider_message_id: "fake-out-#{intent.id}", store_profile_id: context.store_profile_id}}
end
