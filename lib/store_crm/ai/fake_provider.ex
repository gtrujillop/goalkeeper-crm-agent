defmodule StoreCRM.AI.FakeProvider do
  @moduledoc """
  Deterministic AI provider for local development and automated tests.

  It allows the application and agent orchestration to be developed without an
  API key or usage charges.
  """

  @behaviour StoreCRM.AI.Provider

  @impl true
  def respond(request) do
    scenario = get_in(request, [:metadata, :scenario]) || :normal
    iteration = get_in(request, [:metadata, :iteration]) || 1

    case scenario do
      :provider_failure ->
        {:error, :provider_unavailable}

      :low_confidence ->
        ok("No tengo suficiente certeza.", [], 0.2, iteration)

      :disallowed ->
        ok("", [%{name: "issue_refund", arguments: %{}}], 1.0, iteration)

      :tool ->
        tool_response(iteration)

      :loop ->
        ok("", [%{name: "search_products", arguments: %{surface: "sintética"}}], 1.0, iteration)

      :token_limit ->
        ok("Respuesta demasiado extensa", [], 1.0, iteration, %{
          input_tokens: 1_500,
          output_tokens: 1_500
        })

      _ ->
        ok(response_message(request.messages), [], 0.99, iteration)
    end
  end

  defp tool_response(1),
    do: ok("", [%{name: "search_products", arguments: %{surface: "sintética"}}], 1.0, 1)

  defp tool_response(iteration),
    do: ok("Te recomiendo el Guante Pro Turf por $189.900 COP.", [], 0.99, iteration)

  defp ok(message, calls, confidence, iteration, usage \\ %{input_tokens: 40, output_tokens: 20}) do
    {:ok,
     %{
       message: message,
       tool_calls: calls,
       confidence: confidence,
       usage: usage,
       provider_metadata: %{
         provider: :fake,
         model: "deterministic-local",
         request_id: "fake-#{iteration}"
       }
     }}
  end

  defp response_message([]), do: "¿Cómo puedo ayudarte a encontrar el equipo de arquero adecuado?"

  defp response_message(messages) do
    last_message = List.last(messages)
    content = Map.get(last_message, :content) || Map.get(last_message, "content") || ""

    "Recibí tu mensaje: #{content}"
  end
end
