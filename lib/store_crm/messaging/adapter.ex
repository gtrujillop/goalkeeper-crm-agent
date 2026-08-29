defmodule StoreCRM.Messaging.Adapter do
  @callback deliver(map(), map()) :: {:ok, map()} | {:error, term()}
end
