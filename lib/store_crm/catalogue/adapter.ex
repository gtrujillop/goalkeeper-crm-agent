defmodule StoreCRM.Catalogue.Adapter do
  @callback execute(String.t(), map(), map()) :: {:ok, map()} | {:error, term()}
end
