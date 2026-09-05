defmodule StoreCRMWeb.CRMLive do
  use StoreCRMWeb, :live_view
  alias StoreCRM.{CRM, Conversations, Stores}

  @impl true
  def mount(_params, _session, socket) do
    store = Stores.get_profile_by_slug!("colombia")

    if connected?(socket), do: Conversations.subscribe(store.id)

    {:ok,
     socket
     |> assign(:store, store)
     |> assign(:selected, nil)
     |> assign(:search_query, "")
     |> assign_forms()
     |> load_inbox("")}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket), do: {:noreply, select(socket, id)}
  def handle_params(_, _uri, socket), do: {:noreply, assign(socket, :selected, nil)}

  @impl true
  def handle_info({:conversation_changed, conversation_id}, socket) do
    socket = load_inbox(socket, socket.assigns.search_query)

    socket =
      case socket.assigns.selected do
        %{conversation: %{id: ^conversation_id}} -> select(socket, conversation_id)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket),
    do:
      {:noreply,
       socket
       |> assign(:search_form, to_form(%{"query" => query}, as: :search))
       |> load_inbox(query)}

  def handle_event("select", %{"id" => id}, socket),
    do: {:noreply, push_patch(socket, to: ~p"/crm/conversations/#{id}")}

  def handle_event("back_to_inbox", _, socket),
    do: {:noreply, push_patch(socket, to: ~p"/crm")}

  def handle_event("takeover", _, socket) do
    selected = socket.assigns.selected
    {:ok, _} = CRM.set_automation(socket.assigns.store, selected.conversation.id, false)

    {:noreply,
     socket
     |> select(selected.conversation.id)
     |> load_inbox("")
     |> put_flash(:info, "Tomaste la conversación. La automatización quedó pausada.")}
  end

  def handle_event("resume", _, socket) do
    {:ok, _} =
      CRM.set_automation(socket.assigns.store, socket.assigns.selected.conversation.id, true)

    {:noreply, socket |> select(socket.assigns.selected.conversation.id) |> load_inbox("")}
  end

  def handle_event("assign", _, socket) do
    {:ok, _} =
      CRM.assign(socket.assigns.store, socket.assigns.selected.conversation.id, "Manager")

    {:noreply, select(socket, socket.assigns.selected.conversation.id)}
  end

  def handle_event("reply", %{"reply" => %{"content" => content}}, socket) do
    if String.trim(content) == "" do
      {:noreply, put_flash(socket, :error, "Escribe un mensaje antes de enviarlo.")}
    else
      conversation = socket.assigns.selected.conversation

      if conversation.automation_enabled do
        {:ok, _} = CRM.set_automation(socket.assigns.store, conversation.id, false)
      end

      case CRM.manager_reply(
             socket.assigns.store,
             conversation.id,
             content
           ) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:reply_form, to_form(%{"content" => ""}, as: :reply))
           |> select(socket.assigns.selected.conversation.id)}

        {:error, _} ->
          {:noreply,
           socket
           |> select(socket.assigns.selected.conversation.id)
           |> put_flash(:error, "No pudimos entregar el mensaje. Quedó registrado para revisión.")}
      end
    end
  end

  def handle_event("save_profile", %{"profile" => attrs}, socket) do
    attrs = Map.put(attrs, "profile_confidence", "confirmed")

    {:ok, _} =
      CRM.update_profile(socket.assigns.store, socket.assigns.selected.customer.id, attrs)

    {:noreply,
     socket
     |> select(socket.assigns.selected.conversation.id)
     |> load_inbox("")
     |> put_flash(:info, "Perfil confirmado.")}
  end

  def handle_event("add_note", %{"note" => attrs}, socket) do
    {:ok, _} =
      CRM.add_note(
        socket.assigns.store,
        socket.assigns.selected.conversation,
        Map.put(attrs, "author", "Manager")
      )

    {:noreply,
     socket
     |> assign(:note_form, to_form(%{"body" => ""}, as: :note))
     |> select(socket.assigns.selected.conversation.id)}
  end

  def handle_event("add_task", %{"task" => attrs}, socket) do
    {:ok, _} = CRM.add_task(socket.assigns.store, socket.assigns.selected.conversation, attrs)

    {:noreply,
     socket
     |> assign(:task_form, to_form(%{"title" => ""}, as: :task))
     |> select(socket.assigns.selected.conversation.id)}
  end

  def handle_event("complete_task", %{"id" => id}, socket) do
    {:ok, _} = CRM.complete_task(socket.assigns.store, id)
    {:noreply, select(socket, socket.assigns.selected.conversation.id)}
  end

  def handle_event("add_opportunity", %{"opportunity" => attrs}, socket) do
    {:ok, _} =
      CRM.add_opportunity(socket.assigns.store, socket.assigns.selected.customer.id, attrs)

    {:noreply,
     socket
     |> assign(:opportunity_form, to_form(%{"title" => "", "stage" => "new"}, as: :opportunity))
     |> select(socket.assigns.selected.conversation.id)}
  end

  defp assign_forms(socket) do
    socket
    |> assign(:search_form, to_form(%{"query" => ""}, as: :search))
    |> assign(:reply_form, to_form(%{"content" => ""}, as: :reply))
    |> assign(:note_form, to_form(%{"body" => ""}, as: :note))
    |> assign(:task_form, to_form(%{"title" => ""}, as: :task))
    |> assign(:opportunity_form, to_form(%{"title" => "", "stage" => "new"}, as: :opportunity))
  end

  defp load_inbox(socket, query) do
    items = CRM.inbox(socket.assigns.store, query)

    socket
    |> assign(:search_query, query)
    |> assign(:inbox_empty?, items == [])
    |> assign(:inbox_count, length(items))
    |> assign(
      :attention_count,
      Enum.count(items, &(&1.state in ["waiting_for_human", "human_owned"]))
    )
    |> stream(:conversations, items, reset: true)
  end

  defp select(socket, id) do
    selected = CRM.workspace(socket.assigns.store, id)

    socket
    |> assign(:selected, selected)
    |> assign(
      :profile_form,
      to_form(%{"name" => selected.customer.name || "", "email" => selected.customer.email || ""},
        as: :profile
      )
    )
    |> stream(:messages, selected.messages, reset: true)
  end

  defp customer_label(%{customer: %{name: name}}) when is_binary(name) and name != "", do: name
  defp customer_label(%{customer: customer}), do: "Cliente #{String.slice(customer.id, 0, 6)}"
  defp money(amount, currency), do: "#{currency} #{Decimal.round(amount, 0)}"
  defp message_actor(%{direction: "inbound"}), do: "Cliente"
  defp message_actor(%{source: "manager"}), do: "Manager"
  defp message_actor(%{source: "agent"}), do: "Agente IA"
  defp message_actor(_), do: "Sistema"
  defp state_label(%{state: "waiting_for_human"}), do: "Necesita atención"
  defp state_label(%{state: "human_owned"}), do: "En atención humana"
  defp state_label(%{state: "waiting_for_customer"}), do: "Esperando cliente"
  defp state_label(_), do: "IA atendiendo"
  defp local_time(nil, _store), do: "—"

  defp local_time(datetime, store) do
    case DateTime.shift_zone(datetime, store.timezone) do
      {:ok, local} -> Calendar.strftime(local, "%d/%m/%Y %H:%M")
      _ -> Calendar.strftime(datetime, "%d/%m/%Y %H:%M UTC")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="crm-workspace" class="space-y-4">
        <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p class="text-xs font-bold uppercase tracking-[.2em] text-emerald-700">{@store.name}</p>
            <h1 class="mt-1 text-3xl font-bold tracking-tight text-slate-950">Conversaciones</h1>
            <p class="mt-1 text-sm text-slate-600">
              Atiende clientes por WhatsApp y decide cuándo interviene la IA.
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <div class="flex items-center gap-2 rounded-full bg-amber-50 px-3 py-2 text-xs font-bold text-amber-800 ring-1 ring-amber-200">
              <span class="size-2 rounded-full bg-amber-500"></span>
              {@attention_count} por atender
            </div>
            <span
              id="active-store"
              class="w-fit rounded-full bg-emerald-50 px-3 py-2 text-xs font-bold text-emerald-800 ring-1 ring-emerald-200"
            >{@store.market} · {@store.currency}</span>
          </div>
        </header>
        <div class="grid min-h-[72vh] overflow-hidden rounded-[1.75rem] border border-slate-200 bg-white shadow-[0_18px_60px_-30px_rgba(15,23,42,.3)] lg:grid-cols-[24rem_1fr]">
          <aside class={[
            "border-b border-slate-200 bg-slate-50/80 lg:block lg:border-b-0 lg:border-r",
            @selected && "hidden"
          ]}>
            <div class="border-b border-slate-200 bg-white/80 p-4 backdrop-blur">
              <div class="mb-3 flex items-center justify-between">
                <h2 class="text-sm font-bold text-slate-950">Bandeja</h2>
                <span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-600">
                  {@inbox_count}
                </span>
              </div>
              <.form for={@search_form} id="customer-search-form" phx-change="search">
                <.input
                  field={@search_form[:query]}
                  type="search"
                  placeholder="Buscar cliente o teléfono"
                  phx-debounce="250"
                  class="h-11 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 text-sm outline-none transition focus:border-emerald-600 focus:bg-white focus:ring-4 focus:ring-emerald-100"
                />
              </.form>
            </div>
            <div
              id="conversation-inbox"
              phx-update="stream"
              class="max-h-[38vh] overflow-y-auto lg:max-h-[64vh]"
            >
              <div id="inbox-empty" class="hidden only:block p-8 text-center text-sm text-slate-500">
                No encontramos clientes.
              </div>
              <button
                :for={{id, item} <- @streams.conversations}
                id={id}
                type="button"
                phx-click="select"
                phx-value-id={item.id}
                class={[
                  "group block w-full border-b border-slate-200/80 p-4 text-left transition duration-200 hover:bg-white",
                  @selected && @selected.conversation.id == item.id &&
                    "bg-white shadow-[inset_4px_0_0_#047857]"
                ]}
              >
                <div class="flex items-start gap-3">
                  <span class={[
                    "flex size-10 shrink-0 items-center justify-center rounded-full text-sm font-bold",
                    item.state in ["waiting_for_human", "human_owned"] &&
                      "bg-amber-100 text-amber-800",
                    item.state not in ["waiting_for_human", "human_owned"] &&
                      "bg-emerald-100 text-emerald-800"
                  ]}>
                    {customer_label(item) |> String.first() |> String.upcase()}
                  </span>
                  <div class="min-w-0 flex-1">
                    <div class="flex items-start justify-between gap-2">
                      <span class="truncate font-bold text-slate-950">{customer_label(item)}</span>
                      <span class="shrink-0 text-[11px] text-slate-400">
                        {local_time(item.customer.last_interaction_at, @store)}
                      </span>
                    </div>
                    <div class="mt-1.5 flex items-center justify-between gap-2">
                      <span class={[
                        "inline-flex items-center gap-1.5 rounded-full px-2 py-1 text-[11px] font-bold",
                        item.state in ["waiting_for_human", "human_owned"] &&
                          "bg-amber-100 text-amber-800",
                        item.state not in ["waiting_for_human", "human_owned"] &&
                          "bg-emerald-100 text-emerald-800"
                      ]}>
                        <span class="size-1.5 rounded-full bg-current"></span>
                        {state_label(item)}
                      </span>
                      <.icon
                        name="hero-chevron-right"
                        class="size-4 text-slate-300 transition group-hover:translate-x-0.5 group-hover:text-emerald-700"
                      />
                    </div>
                  </div>
                </div>
              </button>
            </div>
          </aside>
          <section
            :if={is_nil(@selected)}
            id="conversation-empty"
            class="flex items-center justify-center p-10 text-center"
          >
            <div class="max-w-sm">
              <span class="mx-auto flex size-16 items-center justify-center rounded-2xl bg-emerald-50 ring-1 ring-emerald-100">
                <.icon name="hero-chat-bubble-left-right" class="size-8 text-emerald-700" />
              </span>
              <h2 class="mt-5 text-lg font-bold text-slate-950">Selecciona una conversación</h2>
              <p class="mt-2 text-sm leading-6 text-slate-500">
                Revisa primero las que necesitan atención. Podrás tomar el control de la IA con un solo toque.
              </p>
            </div>
          </section>
          <section :if={@selected} id="conversation-detail" class="min-w-0">
            <div class="flex flex-col gap-4 border-b border-slate-200 bg-white p-4 sm:flex-row sm:items-center sm:justify-between sm:px-5">
              <div class="flex min-w-0 items-center gap-3">
                <button
                  id="back-to-inbox"
                  phx-click="back_to_inbox"
                  aria-label="Volver a conversaciones"
                  class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-slate-700 transition hover:bg-slate-200 lg:hidden"
                >
                  <.icon name="hero-arrow-left" class="size-5" />
                </button>
                <span class="flex size-11 shrink-0 items-center justify-center rounded-full bg-slate-900 font-bold text-white">
                  {customer_label(@selected) |> String.first() |> String.upcase()}
                </span>
                <div class="min-w-0">
                  <h2 class="truncate text-lg font-bold text-slate-950">
                    {customer_label(@selected)}
                  </h2><p class="truncate text-sm text-slate-500">
                    {@selected.identity && @selected.identity.normalized_value}
                  </p>
                </div>
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <button
                  id="assign-button"
                  phx-click="assign"
                  class="rounded-xl bg-slate-100 px-3 py-2.5 text-xs font-bold text-slate-700 transition hover:bg-slate-200"
                >{if(@selected.conversation.assigned_to,
                  do: "Asignada a #{@selected.conversation.assigned_to}",
                  else: "Asignarme"
                )}</button>
                <button
                  :if={@selected.conversation.automation_enabled}
                  id="takeover-button"
                  phx-click="takeover"
                  aria-pressed="false"
                  class="group flex items-center gap-3 rounded-xl bg-emerald-50 py-2 pl-3 pr-2 text-left ring-1 ring-emerald-200 transition hover:bg-emerald-100 phx-click-loading:opacity-60"
                >
                  <span>
                    <span class="block text-[10px] font-bold uppercase tracking-wider text-emerald-700">Control</span>
                    <span class="block text-xs font-bold text-emerald-950">IA atendiendo</span>
                  </span>
                  <span class="relative h-6 w-11 rounded-full bg-emerald-700 shadow-inner">
                    <span class="absolute right-1 top-1 size-4 rounded-full bg-white shadow-sm transition group-hover:scale-105"></span>
                  </span>
                </button><button
                  :if={!@selected.conversation.automation_enabled}
                  id="resume-button"
                  phx-click="resume"
                  aria-pressed="true"
                  class="group flex items-center gap-3 rounded-xl bg-amber-50 py-2 pl-3 pr-2 text-left ring-1 ring-amber-300 transition hover:bg-amber-100 phx-click-loading:opacity-60"
                >
                  <span>
                    <span class="block text-[10px] font-bold uppercase tracking-wider text-amber-700">Control</span>
                    <span class="block text-xs font-bold text-amber-950">Atención humana</span>
                  </span>
                  <span class="relative h-6 w-11 rounded-full bg-amber-500 shadow-inner">
                    <span class="absolute left-1 top-1 size-4 rounded-full bg-white shadow-sm transition group-hover:scale-105"></span>
                  </span>
                </button>
              </div>
            </div>
            <div
              :if={@selected.conversation.state == "waiting_for_human"}
              id="intervention-banner"
              class="flex flex-col gap-3 border-b border-amber-200 bg-amber-50 px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:px-5"
            >
              <div class="flex items-center gap-3">
                <span class="flex size-9 shrink-0 items-center justify-center rounded-full bg-amber-100 text-amber-800">
                  <.icon name="hero-hand-raised" class="size-5" />
                </span>
                <div>
                  <p class="text-sm font-bold text-amber-950">La IA solicitó intervención</p>
                  <p class="text-xs text-amber-800">
                    Revisa el contexto y toma la conversación para responder.
                  </p>
                </div>
              </div>
              <button
                id="intervention-takeover-button"
                phx-click="takeover"
                class="rounded-xl bg-amber-900 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-amber-800"
              >
                Tomar conversación
              </button>
            </div>
            <div class="grid 2xl:grid-cols-[1fr_19rem]">
              <div class="border-b border-slate-200 2xl:border-b-0 2xl:border-r">
                <div
                  id="message-timeline"
                  phx-update="stream"
                  class="h-[32vh] min-h-64 space-y-3 overflow-y-auto bg-[#f5f7f6] p-4 sm:h-[52vh] sm:min-h-80 sm:p-6 lg:h-[55vh]"
                >
                  <article
                    :for={{id, message} <- @streams.messages}
                    id={id}
                    class={[
                      "max-w-[88%] rounded-2xl px-4 py-3 text-sm leading-6 shadow-sm ring-1 ring-black/5 sm:max-w-[75%]",
                      message.direction == "inbound" && "rounded-tl-md bg-white text-slate-900",
                      message.source == "agent" &&
                        "ml-auto rounded-tr-md bg-emerald-100 text-emerald-950",
                      message.source == "manager" && "ml-auto rounded-tr-md bg-slate-900 text-white",
                      message.source not in ["agent", "manager", "whatsapp"] &&
                        "mx-auto bg-blue-50 text-blue-900"
                    ]}
                  >
                    <p class="mb-1 text-[10px] font-bold uppercase tracking-wider opacity-60">
                      {message_actor(message)}
                    </p><p>{message.content}</p><p class="mt-1 text-[10px] opacity-60">
                      {local_time(message.occurred_at, @store)} · {message.status}
                    </p>
                  </article>
                </div>
                <.form
                  for={@reply_form}
                  id="manager-reply-form"
                  phx-submit="reply"
                  class="border-t border-slate-200 bg-white p-4"
                >
                  <div
                    :if={@selected.conversation.automation_enabled}
                    class="mb-2 flex items-center gap-1.5 text-xs font-medium text-amber-700"
                  >
                    <.icon name="hero-information-circle" class="size-4" />
                    Al responder, tomarás la conversación y la IA se pausará.
                  </div>
                  <div class="flex items-end gap-2">
                    <div class="min-w-0 flex-1">
                      <.input
                        field={@reply_form[:content]}
                        type="textarea"
                        rows="1"
                        placeholder="Responder por WhatsApp…"
                        class="min-h-12 w-full resize-none rounded-2xl border border-slate-300 bg-slate-50 px-4 py-3 text-sm outline-none transition focus:border-emerald-600 focus:bg-white focus:ring-4 focus:ring-emerald-100"
                      />
                    </div>
                    <button
                      id="send-manager-reply"
                      aria-label="Enviar mensaje por WhatsApp"
                      class="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-emerald-950 text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-emerald-800 hover:shadow-md phx-submit-loading:opacity-60"
                    ><.icon name="hero-paper-airplane" class="size-5" /></button>
                  </div>
                </.form>
              </div>
              <aside class="space-y-5 p-4">
                <div>
                  <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Perfil
                    <span class="text-emerald-700">{@selected.customer.profile_confidence}</span>
                  </h3><.form
                    for={@profile_form}
                    id="customer-profile-form"
                    phx-submit="save_profile"
                    class="mt-2 space-y-2"
                  >
                    <.input field={@profile_form[:name]} placeholder="Nombre" /><.input
                      field={@profile_form[:email]}
                      type="email"
                      placeholder="Correo"
                    /><button class="text-sm font-bold text-emerald-700">Confirmar datos</button>
                  </.form>
                </div>
                <div>
                  <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500">Notas</h3><.form
                    for={@note_form}
                    id="note-form"
                    phx-submit="add_note"
                    class="mt-2 flex gap-2"
                  >
                    <.input field={@note_form[:body]} placeholder="Añadir contexto" /><button class="font-bold text-emerald-700">+</button>
                  </.form><div id="notes" class="mt-2 space-y-2">
                    <p
                      :for={note <- @selected.notes}
                      id={"note-#{note.id}"}
                      class="rounded-xl bg-slate-50 p-2 text-xs"
                    >
                      {note.body}
                    </p>
                  </div>
                </div>
                <div>
                  <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Seguimiento
                  </h3><.form
                    for={@task_form}
                    id="task-form"
                    phx-submit="add_task"
                    class="mt-2 flex gap-2"
                  >
                    <.input field={@task_form[:title]} placeholder="Próximo paso" /><button class="font-bold text-emerald-700">+</button>
                  </.form><div id="tasks" class="mt-2 space-y-2">
                    <button
                      :for={task <- @selected.tasks}
                      id={"task-#{task.id}"}
                      phx-click="complete_task"
                      phx-value-id={task.id}
                      class={[
                        "block w-full rounded-xl p-2 text-left text-xs",
                        task.status == "done" && "bg-emerald-50 line-through",
                        task.status == "open" && "bg-amber-50"
                      ]}
                    >{task.title}</button>
                  </div>
                </div>
                <div>
                  <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Oportunidad
                  </h3><.form
                    for={@opportunity_form}
                    id="opportunity-form"
                    phx-submit="add_opportunity"
                    class="mt-2 space-y-2"
                  >
                    <.input field={@opportunity_form[:title]} placeholder="Ej. Guantes profesionales" /><.input
                      field={@opportunity_form[:stage]}
                      type="select"
                      options={[
                        {"Nueva", "new"},
                        {"Calificada", "qualified"},
                        {"Checkout", "checkout"},
                        {"Ganada", "won"}
                      ]}
                    /><button class="text-sm font-bold text-emerald-700">Crear oportunidad</button>
                  </.form>
                </div>
                <div id="order-summaries">
                  <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Pedidos Shopify
                  </h3><a
                    :for={order <- @selected.orders}
                    id={"order-#{order.id}"}
                    href={order.shopify_admin_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="mt-2 block rounded-xl border border-slate-200 p-3 transition hover:border-emerald-500"
                  ><span class="font-bold">{order.order_name}</span><span class="block text-xs text-slate-500">{money(
                    order.total,
                    order.currency
                  )} · {order.status}</span></a><p
                    :if={@selected.orders == []}
                    class="mt-2 text-xs text-slate-400"
                  >
                    Sin pedidos vinculados.
                  </p>
                </div>
              </aside>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
