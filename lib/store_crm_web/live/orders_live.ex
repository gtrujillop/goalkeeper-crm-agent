defmodule StoreCRMWeb.OrdersLive do
  use StoreCRMWeb, :live_view
  alias StoreCRM.{Attribution, Stores, Conversations}
  alias StoreCRM.Commerce.Orders

  @impl true
  def mount(_params, _session, socket) do
    store = Stores.get_profile_by_slug!("colombia")
    if connected?(socket), do: Conversations.subscribe(store.id)

    {:ok,
     socket
     |> assign(:store, store)
     |> assign(:model, :first)
     |> assign(:review_only, false)
     |> refresh()}
  end

  @impl true
  def handle_info({:conversation_changed, _}, socket), do: {:noreply, refresh(socket)}

  @impl true
  def handle_event("model", %{"model" => model}, socket) when model in ["first", "last"] do
    {:noreply,
     socket |> assign(:model, if(model == "first", do: :first, else: :last)) |> refresh()}
  end

  def handle_event("review", _, socket),
    do: {:noreply, socket |> assign(:review_only, not socket.assigns.review_only) |> refresh()}

  def handle_event("follow_up", %{"id" => id}, socket) do
    case Orders.start_follow_up(socket.assigns.store, id) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Seguimiento de entrega creado.") |> refresh()}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Revisa la identidad antes de crear el seguimiento.")}
    end
  end

  def handle_event("complete_task", %{"id" => id}, socket) do
    {:ok, _} = StoreCRM.CRM.complete_task(socket.assigns.store, id)
    {:noreply, refresh(socket)}
  end

  defp refresh(socket) do
    import Ecto.Query
    rows = Attribution.report(socket.assigns.store)

    tasks =
      StoreCRM.Repo.all(
        from t in StoreCRM.CRM.FollowUpTask,
          where:
            t.store_profile_id == ^socket.assigns.store.id and not is_nil(t.order_summary_id),
          order_by: [asc: t.due_at]
      )

    socket
    |> assign(:count, length(rows))
    |> stream(
      :revenue,
      Enum.map(
        Attribution.revenue(rows, socket.assigns.model),
        &Map.put(&1, :id, "#{&1.currency}-#{&1.source}")
      ),
      reset: true
    )
    |> stream(
      :orders,
      Enum.filter(rows, &(not socket.assigns.review_only or &1.order.reconciliation_required)),
      reset: true
    )
    |> stream(:tasks, tasks, reset: true)
  end

  defp channel_label("whatsapp"), do: "WhatsApp"
  defp channel_label("assisted_shopify"), do: "Shopify · asistida"
  defp channel_label(_), do: "Shopify · directa"
  defp payment_label("bank_transfer"), do: "Transferencia bancaria"
  defp payment_label("collect_on_delivery"), do: "Contraentrega por recaudar"
  defp payment_label("pending_transfer"), do: "Transferencia pendiente"
  defp payment_label("paid"), do: "Pago recibido"
  defp payment_label("mercado_pago_shopify"), do: "Mercado Pago"
  defp payment_label("unknown"), do: "Desconocido"
  defp payment_label(value), do: value

  defp evidence(nil), do: "Desconocido · sin evidencia"
  defp evidence(touch), do: "#{touch.source} · #{touch.confidence}"

  defp money(value, currency, store),
    do: StoreCRM.Catalogue.Price.format(Decimal.to_string(value), currency, store.default_locale)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-7xl space-y-8 px-4 py-6 sm:px-8" id="orders-workspace">
        <header class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-widest text-emerald-700">
              {@store.name}
            </p><h1 class="mt-2 text-3xl font-semibold tracking-tight">Pedidos y atribución</h1><p class="mt-2 text-sm text-slate-500">
              {@count} pedidos · Evidencia de compra y próximos pasos
            </p>
          </div>
          <.link
            navigate={~p"/crm"}
            class="rounded-xl border border-slate-200 px-4 py-2 text-sm hover:bg-slate-50"
          >Volver a conversaciones</.link>
        </header>
        <section class="rounded-2xl border border-slate-200 bg-slate-50 p-5" id="attribution-report">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <h2 class="font-semibold">Ingresos pagados por adquisición</h2><div class="flex gap-2">
              <button
                id="first-touch"
                phx-click="model"
                phx-value-model="first"
                aria-pressed={to_string(@model == :first)}
                class="rounded-lg border bg-white px-3 py-2 text-sm hover:border-emerald-500"
              >Primer contacto</button>
              <button
                id="last-touch"
                phx-click="model"
                phx-value-model="last"
                aria-pressed={to_string(@model == :last)}
                class="rounded-lg border bg-white px-3 py-2 text-sm hover:border-emerald-500"
              >Último contacto</button>
            </div>
          </div>
          <p class="mt-2 text-xs text-slate-500">
            Importe bruto de pedidos pagados; reembolsos separados por pedido. Monedas separadas. La adquisición desconocida permanece incluida.
          </p>
          <div id="revenue-list" phx-update="stream" class="mt-4 grid gap-3 sm:grid-cols-3">
            <div :for={{id, row} <- @streams.revenue} id={id} class="rounded-xl bg-white p-4">
              <p class="text-sm text-slate-500">{row.source} · {row.orders} pedidos</p><p class="mt-1 text-xl font-semibold">
                {money(row.revenue, row.currency, @store)}
              </p>
            </div>
          </div>
        </section>
        <button
          id="review-filter"
          phx-click="review"
          aria-pressed={to_string(@review_only)}
          class="rounded-xl border border-amber-200 bg-amber-50 px-4 py-2 text-sm text-amber-900 hover:bg-amber-100"
        >{if @review_only, do: "Mostrar todos los pedidos", else: "Ver conciliación de identidad"}</button>
        <div id="order-list" phx-update="stream" class="space-y-4">
          <p
            id="orders-empty"
            class="hidden rounded-2xl border border-dashed p-10 text-center text-slate-500 only:block"
          >
            Registra una venta desde su conversación de WhatsApp. Las compras de Shopify también aparecerán aquí.
          </p>
          <article
            :for={{id, row} <- @streams.orders}
            id={id}
            class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
          >
            <div class="flex flex-wrap justify-between gap-4">
              <div>
                <h2 class="text-lg font-semibold">{row.order.order_name}</h2><p class="text-sm text-slate-500">
                  {channel_label(row.order.order_channel)} · {row.order.status} · {row.order.fulfillment_status}
                </p>
              </div><div class="text-right">
                <p class="text-lg font-semibold">
                  {money(row.order.total, row.order.currency, @store)}
                </p><.link
                  :if={row.order.shopify_admin_url}
                  href={row.order.shopify_admin_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-sm text-emerald-700 hover:underline"
                >Abrir en Shopify ↗</.link>
                <.link
                  :if={row.order.order_channel == "whatsapp"}
                  id={"manage-native-#{row.order.id}"}
                  navigate={~p"/crm/orders/#{row.order.id}"}
                  class="text-sm font-semibold text-emerald-700 hover:underline"
                >Gestionar pedido de WhatsApp →</.link>
              </div>
            </div>
            <div class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
              <div>
                <p class="text-slate-500">Pago y entrega</p><p>
                  {payment_label(row.order.payment_path)} · {payment_label(row.order.financial_status)} · {row.order.carrier ||
                    "Transportadora desconocida"}
                </p><p>Reembolsado: {money(row.order.refunded_total, row.order.currency, @store)}</p>
              </div>
              <div>
                <p class="text-slate-500">Identidad</p><p>
                  {row.order.identity_evidence["source"] || "unknown"} · {row.order.identity_evidence[
                    "confidence"
                  ] || "unknown"}
                </p><p :if={row.order.reconciliation_required} class="font-semibold text-amber-700">
                  Requiere conciliación de identidad
                </p>
              </div>
              <div>
                <p class="text-slate-500">Primer contacto</p><p>{evidence(row.first)}</p>
              </div><div>
                <p class="text-slate-500">Último contacto</p><p>{evidence(row.last)}</p>
              </div>
            </div>
            <details class="mt-4 rounded-xl bg-slate-50 p-3 text-xs">
              <summary class="cursor-pointer font-medium">
                Ver evidencia de atribución e identidad
              </summary><pre class="mt-3 overflow-auto whitespace-pre-wrap break-all">{Jason.encode!(%{identity: row.order.identity_evidence, first: row.first && %{id: row.first.id, at: row.first.occurred_at, evidence: row.first.evidence}, last: row.last && %{id: row.last.id, at: row.last.occurred_at, evidence: row.last.evidence}}, pretty: true)}</pre>
            </details>
            <details class="mt-3 rounded-xl bg-slate-50 p-3 text-xs">
              <summary class="cursor-pointer font-medium">Historial del pedido</summary><pre class="mt-3 overflow-auto whitespace-pre-wrap break-all">{Jason.encode!(row.events, pretty: true)}</pre>
            </details>
            <button
              id={"follow-up-#{row.order.id}"}
              phx-click="follow_up"
              phx-value-id={row.order.id}
              disabled={row.order.reconciliation_required}
              class="mt-4 rounded-xl bg-emerald-700 px-4 py-2 text-sm font-semibold text-white transition hover:bg-emerald-800 disabled:opacity-40"
              phx-disable-with="Creando…"
            >Crear seguimiento de entrega</button>
          </article>
        </div>
        <section>
          <h2 class="mb-4 text-lg font-semibold">Seguimientos de entrega</h2><div
            id="delivery-tasks"
            phx-update="stream"
            class="space-y-2"
          >
            <p id="tasks-empty" class="hidden text-sm text-slate-500 only:block">Sin seguimientos.</p><div
              :for={{id, task} <- @streams.tasks}
              id={id}
              class="flex items-center justify-between gap-3 rounded-xl border p-4"
            >
              <span>{task.title} · {task.status}</span><button
                :if={task.status == "open"}
                id={"complete-#{task.id}"}
                phx-click="complete_task"
                phx-value-id={task.id}
                class="text-sm font-semibold text-emerald-700"
              >Completar</button>
            </div>
          </div>
        </section>
      </main>
    </Layouts.app>
    """
  end
end
