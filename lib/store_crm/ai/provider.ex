defmodule StoreCRM.AI.Provider do
  @moduledoc """
  Provider-neutral boundary for generating an agent response.

  CRM state remains canonical in PostgreSQL. Implementations translate the
  normalized request into provider-specific calls and return observable output.
  """

  @type request :: %{
          required(:instructions) => String.t(),
          required(:messages) => [map()],
          optional(:tools) => [map()],
          optional(:metadata) => map()
        }

  @type response :: %{
          required(:message) => String.t(),
          required(:tool_calls) => [map()],
          required(:provider_metadata) => map(),
          optional(:usage) => map(),
          optional(:confidence) => number()
        }

  @callback respond(request()) :: {:ok, response()} | {:error, term()}
end
