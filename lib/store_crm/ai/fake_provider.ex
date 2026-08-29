defmodule StoreCRM.AI.FakeProvider do
  @moduledoc """
  Deterministic AI provider for local development and automated tests.

  It allows the application and agent orchestration to be developed without an
  API key or usage charges.
  """

  @behaviour StoreCRM.AI.Provider

  @impl true
  def respond(request) do
    {:ok,
     %{
       message: response_message(request.messages),
       tool_calls: [],
       provider_metadata: %{provider: :fake, model: "deterministic-local"}
     }}
  end

  defp response_message([]), do: "How can I help you find the right goalkeeper gear?"

  defp response_message(messages) do
    last_message = List.last(messages)
    content = Map.get(last_message, :content) || Map.get(last_message, "content") || ""

    "I received your message: #{content}"
  end
end
