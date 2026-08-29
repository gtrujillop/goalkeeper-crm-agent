defmodule StoreCRM.Agent.Engine do
  alias StoreCRM.Repo
  alias StoreCRM.Agent.{AgentRun, ToolCall}
  alias StoreCRM.Conversations
  alias StoreCRM.Conversations.{Conversation, Handoff, Message}

  @prompt_version "sales-assistant-v1"
  @prompt "Ayuda al cliente en español colombiano. Usa herramientas para datos comerciales y solicita ayuda humana cuando no puedas responder con certeza."
  @allowed_tools ~w(search_products create_cart)

  def process_inbound(store, attrs, opts \\ []) when not is_nil(store.id) do
    with {:ok, ingestion} <- Conversations.ingest(store, attrs) do
      if ingestion.duplicate? do
        {:ok, ingestion}
      else
        if ingestion.conversation.state in ["waiting_for_human", "human_owned"] do
          {:ok, Map.put(ingestion, :automation_suppressed?, true)}
        else
          run(store, ingestion, opts)
        end
      end
    end
  end

  defp run(store, ingestion, opts) do
    provider = Keyword.get(opts, :ai_provider, StoreCRM.AI.FakeProvider)
    catalogue = Keyword.get(opts, :catalogue_adapter, StoreCRM.Catalogue.Fake)
    messaging = Keyword.get(opts, :messaging_adapter, StoreCRM.Messaging.Fake)
    scenario = Keyword.get(opts, :scenario, :normal)
    context = context(store, ingestion.conversation)

    run =
      %AgentRun{
        store_profile_id: store.id,
        customer_id: ingestion.customer.id,
        conversation_id: ingestion.conversation.id,
        input_message_id: ingestion.message.id
      }
      |> AgentRun.changeset(%{
        prompt_version: @prompt_version,
        prompt: @prompt,
        provider: provider_name(provider),
        model: "pending",
        context: context,
        outcome: "running"
      })
      |> Repo.insert!()

    limits = %{
      max_tool_calls: limit(store, "max_tool_calls", 3),
      max_tokens: limit(store, "max_tokens", 2_000)
    }

    messages = [%{role: :user, content: ingestion.message.content}]

    case loop(provider, catalogue, run, context, messages, scenario, limits, %{
           iteration: 1,
           calls: 0,
           input_tokens: 0,
           output_tokens: 0
         }) do
      {:ok, response, stats, metadata} ->
        finish(store, ingestion, run, response, stats, metadata, messaging)

      {:handoff, reason, summary, stats, metadata} ->
        handoff(store, ingestion, run, reason, summary, stats, metadata, messaging)
    end
  end

  defp loop(provider, catalogue, run, context, messages, scenario, limits, stats) do
    request = %{
      instructions: @prompt,
      messages: messages,
      tools: tool_schemas(),
      metadata: %{context: context, scenario: scenario, iteration: stats.iteration}
    }

    case provider.respond(request) do
      {:error, reason} ->
        {:handoff, "provider_failure", inspect(reason), stats, %{}}

      {:ok, response} ->
        handle_response(
          provider,
          catalogue,
          run,
          context,
          messages,
          scenario,
          limits,
          stats,
          response
        )
    end
  end

  defp handle_response(
         provider,
         catalogue,
         run,
         context,
         messages,
         scenario,
         limits,
         stats,
         response
       ) do
    usage = Map.get(response, :usage, %{})

    stats = %{
      stats
      | input_tokens: stats.input_tokens + Map.get(usage, :input_tokens, 0),
        output_tokens: stats.output_tokens + Map.get(usage, :output_tokens, 0)
    }

    metadata = Map.get(response, :provider_metadata, %{})

    cond do
      stats.input_tokens + stats.output_tokens > limits.max_tokens ->
        {:handoff, "token_limit", "Se alcanzó el límite de tokens configurado.", stats, metadata}

      Map.get(response, :confidence, 1.0) < 0.6 ->
        {:handoff, "low_confidence", response.message, stats, metadata}

      response.tool_calls == [] ->
        {:ok, response.message, stats, metadata}

      stats.calls + length(response.tool_calls) > limits.max_tool_calls ->
        {:handoff, "tool_limit", "Se alcanzó el límite de herramientas configurado.", stats,
         metadata}

      Enum.any?(response.tool_calls, &(to_string(Map.get(&1, :name)) not in @allowed_tools)) ->
        {:handoff, "disallowed_tool", "La solicitud requiere una acción no autorizada.", stats,
         metadata}

      true ->
        results = Enum.map(response.tool_calls, &execute_tool(catalogue, run, context, &1))

        if Enum.any?(results, &match?(%{"error" => _}, &1)) do
          {:handoff, "commerce_provider_failure", "Shopify no está disponible en este momento.",
           stats, metadata}
        else
          next_messages =
            messages ++
              [
                %{role: :assistant, content: response.message},
                %{role: :tool, content: inspect(results)}
              ]

          next_stats = %{
            stats
            | iteration: stats.iteration + 1,
              calls: stats.calls + length(results)
          }

          loop(provider, catalogue, run, context, next_messages, scenario, limits, next_stats)
        end
    end
  end

  defp execute_tool(catalogue, run, context, call) do
    name = to_string(Map.fetch!(call, :name))
    arguments = Map.get(call, :arguments, %{})
    started = System.monotonic_time(:millisecond)

    tool_context =
      Map.merge(atom_context(context), %{
        customer_id: run.customer_id,
        conversation_id: run.conversation_id
      })

    response =
      case catalogue.execute(name, arguments, tool_context) do
        {:ok, value} when name == "create_cart" ->
          case StoreCRM.Commerce.record_cart(tool_context, value) do
            {:ok, _session} -> {:ok, value}
            {:error, changeset} -> {:error, {:cart_persistence_failed, changeset.errors}}
          end

        other ->
          other
      end

    duration = System.monotonic_time(:millisecond) - started

    {status, result} =
      case response do
        {:ok, value} ->
          {"succeeded", value}

        {:error, reason} ->
          {"failed", %{"error" => inspect(reason)}}
      end

    %ToolCall{store_profile_id: run.store_profile_id, agent_run_id: run.id}
    |> ToolCall.changeset(%{
      name: name,
      arguments: arguments,
      result: result,
      status: status,
      duration_ms: duration
    })
    |> Repo.insert!()

    result
  end

  defp finish(store, ingestion, run, response, stats, metadata, messaging) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    output =
      %Message{
        store_profile_id: store.id,
        customer_id: ingestion.customer.id,
        conversation_id: ingestion.conversation.id
      }
      |> Message.changeset(%{
        direction: "outbound",
        source: "agent",
        provider_message_id: "intent-#{Ecto.UUID.generate()}",
        content: response,
        status: "pending",
        position: Conversations.next_position(ingestion.conversation.id),
        occurred_at: now
      })
      |> Repo.insert!()

    update_run(run, "completed", response, output.id, stats, metadata, nil)

    delivery =
      messaging.deliver(output, %{store_profile_id: store.id, locale: store.default_locale})

    {:ok,
     Map.merge(ingestion, %{
       agent_run: Repo.reload!(run),
       outbound_message: output,
       outbound_intent: delivery
     })}
  end

  defp handoff(store, ingestion, run, reason, summary, stats, metadata, messaging) do
    conversation =
      ingestion.conversation
      |> Conversation.changeset(%{state: "waiting_for_human"})
      |> Repo.update!()

    safe_message = "Te voy a comunicar con una persona del equipo para ayudarte mejor."
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    output =
      %Message{
        store_profile_id: store.id,
        customer_id: ingestion.customer.id,
        conversation_id: conversation.id
      }
      |> Message.changeset(%{
        direction: "outbound",
        source: "agent",
        provider_message_id: "intent-#{Ecto.UUID.generate()}",
        content: safe_message,
        status: "pending",
        position: Conversations.next_position(conversation.id),
        occurred_at: now
      })
      |> Repo.insert!()

    run = update_run(run, "escalated", safe_message, output.id, stats, metadata, summary)

    %Handoff{
      store_profile_id: store.id,
      customer_id: ingestion.customer.id,
      conversation_id: conversation.id,
      agent_run_id: run.id
    }
    |> Handoff.changeset(%{reason: reason, summary: summary})
    |> Repo.insert!()

    delivery =
      messaging.deliver(output, %{store_profile_id: store.id, locale: store.default_locale})

    {:ok,
     Map.merge(ingestion, %{
       conversation: conversation,
       agent_run: run,
       outbound_message: output,
       outbound_intent: delivery
     })}
  end

  defp update_run(run, outcome, result, output_id, stats, metadata, error) do
    usage = stats.input_tokens + stats.output_tokens

    run
    |> AgentRun.changeset(%{
      outcome: outcome,
      result: result,
      output_message_id: output_id,
      iteration_count: stats.iteration,
      input_tokens: stats.input_tokens,
      output_tokens: stats.output_tokens,
      estimated_cost: Decimal.div(Decimal.new(usage), Decimal.new(1_000_000)),
      model: to_string(Map.get(metadata, :model, "unknown")),
      provider_request_id: Map.get(metadata, :request_id),
      error: error
    })
    |> Repo.update!()
  end

  defp context(store, conversation),
    do: %{
      "store_profile_id" => store.id,
      "market" => store.market,
      "locale" => conversation.locale,
      "currency" => store.currency,
      "timezone" => store.timezone,
      "phone_region" => store.phone_region
    }

  defp atom_context(context),
    do: %{
      store_profile_id: context["store_profile_id"],
      locale: context["locale"],
      currency: context["currency"],
      timezone: context["timezone"],
      market: context["market"],
      customer_id: context["customer_id"],
      conversation_id: context["conversation_id"]
    }

  defp limit(store, key, default), do: Map.get(store.agent_limits || %{}, key, default)
  defp provider_name(provider), do: provider |> Module.split() |> Enum.join(".")

  defp tool_schemas,
    do: [
      %{name: "search_products", arguments: %{type: "object"}},
      %{name: "create_cart", arguments: %{type: "object"}}
    ]
end
