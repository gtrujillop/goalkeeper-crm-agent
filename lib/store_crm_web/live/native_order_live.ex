defmodule StoreCRMWeb.NativeOrderLive do
  use StoreCRMWeb, :live_view
  alias StoreCRM.{Stores, Conversations}
  alias StoreCRM.Commerce.{NativeOrders, NativeOrderForm}

  @input "block w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"

  @impl true
  def mount(_, _, socket) do
    store = Stores.get_profile_by_slug!("colombia")
    if connected?(socket), do: Conversations.subscribe(store.id)
    {:ok, assign(socket, store: store, order: nil, input_class: @input)}
  end

  @impl true
  def handle_params(%{"conversation_id" => id}, _, socket) do
    conversation = NativeOrders.conversation!(socket.assigns.store, id)

    initial =
      NativeOrders.initial_form(socket.assigns.store, conversation)
      |> Ecto.Changeset.apply_changes()

    params = %{
      "recipient" => initial.recipient,
      "phone" => initial.phone,
      "payment_path" => "collect_on_delivery",
      "shipping_cost" => "0",
      "items" => %{"0" => %{"quantity" => "1"}}
    }

    options =
      Enum.map(
        NativeOrders.opportunities(socket.assigns.store, conversation.customer_id),
        &{&1.title, &1.id}
      )

    {:noreply,
     socket
     |> assign(:conversation, conversation)
     |> assign(:opportunity_options, options)
     |> assign(:request_id, Ecto.UUID.generate())
     |> assign(:order, nil)
     |> draft(params)}
  end

  def handle_params(%{"id" => id}, _, socket), do: {:noreply, load_order(socket, id)}

  @impl true
  def handle_info({:conversation_changed, _}, socket) do
    # Keep in-progress operator input. Commands reject stale versions on submit.
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"order" => attrs}, socket),
    do: {:noreply, draft(socket, attrs, :validate)}

  def handle_event("add_item", _, socket) do
    items = item_params(socket.assigns.draft_params)

    params =
      Map.put(
        socket.assigns.draft_params,
        "items",
        Enum.take(items ++ [%{"quantity" => "1"}], 20)
      )

    {:noreply, draft(socket, params)}
  end

  def handle_event("remove_item", %{"index" => index}, socket) do
    items = item_params(socket.assigns.draft_params)

    kept =
      items
      |> Enum.with_index()
      |> Enum.reject(fn {_, i} -> to_string(i) == index end)
      |> Enum.map(&elem(&1, 0))

    {:noreply, draft(socket, Map.put(socket.assigns.draft_params, "items", kept))}
  end

  def handle_event("create", %{"order" => attrs}, socket) do
    case NativeOrders.create(
           socket.assigns.store,
           socket.assigns.conversation.id,
           socket.assigns.request_id,
           attrs,
           "Manager"
         ) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pedido de WhatsApp registrado.")
         |> push_navigate(to: ~p"/crm/orders/#{order.id}")}

      {:error, %Ecto.Changeset{} = errors} ->
        {:noreply,
         socket
         |> assign(:draft_params, attrs)
         |> assign(:order_form, to_form(errors, as: :order))}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "No se pudo registrar el pedido. Revisa la oportunidad y vuelve a intentarlo."
         )}
    end
  end

  def handle_event("update_order", %{"update" => attrs}, socket) do
    order = socket.assigns.order

    case NativeOrders.transition(
           socket.assigns.store,
           order.id,
           attrs["action"],
           attrs,
           order.lock_version,
           "Manager"
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_order(order.id)
         |> put_flash(:info, "Cambio registrado en el historial del pedido.")}

      {:error, :stale_order} ->
        {:noreply,
         socket
         |> load_order(order.id)
         |> put_flash(
           :error,
           "El pedido cambió en otra sesión. Revisa su estado antes de continuar."
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:update_form, to_form(attrs, as: :update))
         |> put_flash(:error, error_message(reason))}
    end
  end

  def handle_event("follow_up", _, socket) do
    {:ok, _} =
      StoreCRM.Commerce.Orders.start_follow_up(socket.assigns.store, socket.assigns.order.id)

    {:noreply,
     put_flash(
       socket,
       :info,
       "Seguimiento de entrega disponible en Pedidos y en la conversación."
     )}
  end

  defp draft(socket, params, action \\ nil) do
    changeset = NativeOrderForm.changeset(%NativeOrderForm{}, params) |> Map.put(:action, action)
    socket |> assign(:draft_params, params) |> assign(:order_form, to_form(changeset, as: :order))
  end

  defp item_params(params) do
    case params["items"] || [] do
      items when is_list(items) ->
        items

      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _} ->
          case Integer.parse(key) do
            {i, ""} -> i
            _ -> 0
          end
        end)
        |> Enum.map(&elem(&1, 1))
    end
  end

  defp load_order(socket, id) do
    order = NativeOrders.get!(socket.assigns.store, id)

    socket
    |> assign(:order, order)
    |> assign(
      :conversation,
      NativeOrders.conversation!(socket.assigns.store, order.conversation_id)
    )
    |> assign(
      :update_form,
      to_form(%{"action" => "payment.received", "note" => "", "tracking_number" => ""},
        as: :update
      )
    )
    |> stream(
      :items,
      Enum.with_index(order.snapshot["line_items"] || [], fn item, index ->
        Map.put(item, :id, index)
      end),
      reset: true
    )
    |> stream(:events, NativeOrders.events(socket.assigns.store, id), reset: true)
  end

  defp error_message(:evidence_required), do: "Describe la evidencia o el motivo del cambio."

  defp error_message(:tracking_required),
    do: "Ingresa el número de guía antes de marcar el pedido como enviado."

  defp error_message(_), do: "Este cambio no corresponde al estado actual del pedido."

  defp money(value, currency, store),
    do: StoreCRM.Catalogue.Price.format(to_string(value), currency, store.default_locale)

  defp label("collect_on_delivery"), do: "Pago contraentrega pendiente"
  defp label("pending_transfer"), do: "Transferencia pendiente"
  defp label("bank_transfer"), do: "Transferencia bancaria"
  defp label("paid"), do: "Pago recibido"
  defp label("refunded"), do: "Reembolsado"
  defp label("unfulfilled"), do: "Por enviar"
  defp label("shipped"), do: "Enviado"
  defp label("delivered"), do: "Entregado"
  defp label("returned"), do: "Devuelto"
  defp label("confirmed"), do: "Confirmado"
  defp label("cancelled"), do: "Cancelado"
  defp label(value), do: value
  defp event_label("order.confirmed"), do: "Pedido registrado"
  defp event_label("payment.received"), do: "Pago recibido"
  defp event_label("payment.refunded"), do: "Reembolso registrado"
  defp event_label("shipment.shipped"), do: "Envío registrado"
  defp event_label("shipment.delivered"), do: "Entrega registrada"
  defp event_label("shipment.returned"), do: "Devolución registrada"
  defp event_label("order.cancelled"), do: "Pedido cancelado"
  defp event_label(value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="native-order-workspace" class="mx-auto max-w-5xl space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-bold uppercase tracking-widest text-emerald-700">
              Venta por WhatsApp · {@store.name}
            </p><h1 class="mt-2 text-3xl font-bold tracking-tight text-slate-950">
              {if @order, do: @order.order_name, else: "Registrar pedido"}
            </h1><p class="mt-2 text-sm text-slate-500">
              {@conversation.customer.name || "Cliente de WhatsApp"}
            </p>
          </div><.link
            id="back-to-conversation"
            navigate={~p"/crm/conversations/#{@conversation.id}"}
            class="rounded-xl border border-slate-200 px-4 py-2 text-sm hover:bg-slate-50"
          >Volver a la conversación</.link>
        </header>
        <%= if is_nil(@order) do %>
          <p class="rounded-2xl bg-emerald-50 p-4 text-sm leading-6 text-emerald-900">
            Registra los productos y precios acordados con el cliente. El pedido se gestiona aquí, sin checkout de Shopify. El pago se confirmará por separado cuando lo recibas.
          </p>
          <.form
            for={@order_form}
            id="native-order-form"
            phx-change="validate"
            phx-submit="create"
            class="space-y-6"
          >
            <section class="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 class="mb-4 text-lg font-semibold">Productos acordados</h2>
              <.inputs_for :let={item} field={@order_form[:items]}>
                <div class="mb-4 grid gap-3 rounded-xl bg-slate-50 p-4 sm:grid-cols-2">
                  <.input
                    field={item[:title]}
                    label="Producto"
                    class={@input_class}
                    placeholder="Guantes de portero"
                  />
                  <.input
                    field={item[:variant]}
                    label="Talla / variante"
                    class={@input_class}
                    placeholder="Talla 9 · Negro"
                  />
                  <.input
                    field={item[:quantity]}
                    type="number"
                    min="1"
                    max="100"
                    label="Cantidad"
                    class={@input_class}
                  />
                  <.input
                    field={item[:unit_price]}
                    type="number"
                    min="0"
                    step="0.01"
                    label={"Precio unitario (#{@store.currency})"}
                    class={@input_class}
                  />
                  <button
                    type="button"
                    id={"remove-item-#{item.index}"}
                    phx-click="remove_item"
                    phx-value-index={item.index}
                    class="text-left text-xs font-semibold text-slate-500 hover:text-red-700"
                  >Quitar producto</button>
                </div>
              </.inputs_for>
              <p :for={{message, _} <- @order_form[:items].errors} class="mb-3 text-sm text-red-700">
                {message}
              </p>
              <button
                type="button"
                id="add-native-item"
                phx-click="add_item"
                class="inline-flex items-center gap-2 rounded-xl border border-slate-200 px-3 py-2 text-sm font-semibold hover:bg-slate-50"
              ><.icon name="hero-plus" class="size-4" /> Agregar producto</button>
            </section>
            <section class="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 class="mb-4 text-lg font-semibold">Entrega</h2><div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@order_form[:recipient]}
                  label="Nombre de quien recibe"
                  class={@input_class}
                />
                <.input field={@order_form[:phone]} label="Teléfono de entrega" class={@input_class} />
                <.input
                  field={@order_form[:address]}
                  label="Dirección completa"
                  class={@input_class}
                />
                <.input field={@order_form[:city]} label="Ciudad / municipio" class={@input_class} />
                <.input
                  field={@order_form[:carrier]}
                  label="Transportadora (opcional)"
                  placeholder="TCC"
                  class={@input_class}
                />
                <.input
                  field={@order_form[:shipping_cost]}
                  type="number"
                  min="0"
                  step="0.01"
                  label={"Costo de envío (#{@store.currency})"}
                  class={@input_class}
                />
              </div>
            </section>
            <section class="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 class="mb-4 text-lg font-semibold">Acuerdo de compra</h2><div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@order_form[:payment_path]}
                  type="select"
                  label="Forma de pago"
                  options={[
                    {"Pago contraentrega", "collect_on_delivery"},
                    {"Transferencia bancaria", "bank_transfer"}
                  ]}
                  class={@input_class}
                />
                <.input
                  field={@order_form[:opportunity_id]}
                  type="select"
                  label="Oportunidad relacionada"
                  prompt="Sin oportunidad"
                  options={@opportunity_options}
                  class={@input_class}
                />
                <div class="sm:col-span-2">
                  <.input
                    field={@order_form[:notes]}
                    type="textarea"
                    label="Observaciones del acuerdo"
                    class={@input_class}
                  />
                </div>
              </div><p class="mt-4 text-xs leading-5 text-slate-500">
                El total se calcula con los productos y el envío. Confirmar el pedido no registra un pago ni reserva inventario automáticamente.
              </p>
            </section>
            <button
              id="create-native-order"
              phx-disable-with="Registrando…"
              class="w-full rounded-xl bg-emerald-950 px-5 py-3 text-sm font-bold text-white transition hover:bg-emerald-800"
            >Registrar pedido de WhatsApp</button>
          </.form>
        <% else %>
          <div class="grid gap-4 sm:grid-cols-3">
            <div class="rounded-2xl bg-slate-950 p-5 text-white">
              <p class="text-xs text-slate-300">Total acordado · {label(@order.status)}</p><p
                id="native-order-total"
                class="mt-2 text-2xl font-bold"
              >
                {money(@order.total, @order.currency, @store)}
              </p>
            </div><div class="rounded-2xl border border-amber-200 bg-amber-50 p-5">
              <p class="text-xs text-amber-800">Pago</p><p
                id="native-payment-status"
                class="mt-2 font-semibold"
              >
                {label(@order.financial_status)}
              </p>
            </div><div class="rounded-2xl border border-slate-200 p-5">
              <p class="text-xs text-slate-500">Entrega</p><p
                id="native-delivery-status"
                class="mt-2 font-semibold"
              >
                {label(@order.fulfillment_status)}
              </p>
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <section class="rounded-2xl border border-slate-200 p-5">
              <h2 class="font-semibold">Productos y entrega</h2><div
                id="native-items"
                phx-update="stream"
                class="mt-4 space-y-3"
              >
                <div
                  :for={{id, item} <- @streams.items}
                  id={id}
                  class="border-b border-slate-100 pb-3 text-sm"
                >
                  <p class="font-semibold">{item["title"]} · {item["variant"]}</p><p class="text-slate-500">
                    {item["quantity"]} × {money(item["unit_price"], @order.currency, @store)}
                  </p>
                </div>
              </div><div class="mt-4 space-y-1 text-sm text-slate-600">
                <p>Envío: {money(@order.snapshot["shipping_cost"], @order.currency, @store)}</p><p>
                  {@order.snapshot["recipient"]} · {@order.snapshot["phone"]}
                </p><p>{@order.snapshot["address"]} · {@order.snapshot["city"]}</p><p>
                  {@order.carrier || "Transportadora por definir"} · Guía: {@order.snapshot[
                    "tracking_number"
                  ] || "pendiente"}
                </p><p>{@order.snapshot["notes"]}</p>
              </div>
            </section>
            <section class="rounded-2xl border border-slate-200 p-5">
              <h2 class="font-semibold">Registrar un cambio</h2><p class="mt-2 text-xs leading-5 text-slate-500">
                Confirma el pago cuando hayas recibido el dinero. La entrega contraentrega puede ocurrir antes del recaudo. Los cambios quedan en el historial; no envían dinero ni mensajes.
              </p>
              <.form
                for={@update_form}
                id="native-order-update-form"
                phx-submit="update_order"
                class="mt-4 space-y-4"
              >
                <.input
                  field={@update_form[:action]}
                  type="select"
                  label="Cambio"
                  options={[
                    {"Confirmar pago recibido", "payment.received"},
                    {"Marcar enviado", "shipment.shipped"},
                    {"Marcar entregado", "shipment.delivered"},
                    {"Registrar devolución", "shipment.returned"},
                    {"Cancelar pedido", "order.cancelled"},
                    {"Registrar reembolso completo realizado", "payment.refunded"}
                  ]}
                  class={@input_class}
                />
                <.input
                  field={@update_form[:tracking_number]}
                  label="Número de guía (para envío)"
                  class={@input_class}
                />
                <.input
                  field={@update_form[:note]}
                  type="textarea"
                  label="Evidencia o motivo"
                  placeholder="Referencia de transferencia, confirmación de recaudo o detalle del cambio"
                  class={@input_class}
                />
                <button
                  id="save-native-order-update"
                  phx-disable-with="Guardando…"
                  class="w-full rounded-xl bg-emerald-950 px-4 py-3 text-sm font-bold text-white hover:bg-emerald-800"
                >Guardar cambio</button>
              </.form>
            </section>
          </div>
          <section class="rounded-2xl border border-slate-200 p-5">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <h2 class="font-semibold">Historial del pedido</h2><button
                id="native-follow-up"
                phx-click="follow_up"
                class="rounded-xl border px-3 py-2 text-sm font-semibold hover:bg-slate-50"
              >Crear seguimiento de entrega</button>
            </div><div id="native-order-history" phx-update="stream" class="mt-4 space-y-3">
              <article
                :for={{id, event} <- @streams.events}
                id={id}
                class="rounded-xl bg-slate-50 p-4 text-sm"
              >
                <p class="font-semibold">{event_label(event.kind)}</p><p class="mt-1 text-xs text-slate-500">
                  {event.actor} · {Calendar.strftime(event.inserted_at, "%Y-%m-%d %H:%M UTC")}
                </p><p class="mt-2">{event.evidence["note"]}</p>
              </article>
            </div>
          </section>
        <% end %>
        <.link
          navigate={~p"/crm/orders"}
          class="inline-block text-sm font-semibold text-emerald-700 hover:underline"
        >Ver todos los pedidos y la atribución →</.link>
      </div>
    </Layouts.app>
    """
  end
end
