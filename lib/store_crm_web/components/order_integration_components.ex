defmodule StoreCRMWeb.OrderIntegrationComponents do
  use StoreCRMWeb, :html

  attr :store, :any, required: true
  attr :form, :any, required: true
  attr :status, :map, required: true
  attr :secret_ready, :boolean, required: true
  attr :base_url, :string, required: true
  attr :events, :any, required: true

  def panel(assigns) do
    ~H"""
    <section
      id="order-integration"
      class="overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm"
    >
      <header class="flex flex-wrap items-center justify-between gap-4 border-b border-slate-200 bg-emerald-950 px-5 py-5 text-white sm:px-6">
        <div class="flex items-center gap-3">
          <.icon name="hero-shopping-bag" class="size-6 text-emerald-300" /><div>
            <h2 class="text-lg font-bold">Pedidos y atribución</h2><p class="mt-1 text-xs text-emerald-100">
              Gestiona tus ventas por WhatsApp y consulta también las compras de Shopify.
            </p>
          </div>
        </div>
        <.link
          id="admin-orders-link"
          navigate={~p"/crm/orders"}
          class="inline-flex items-center gap-2 rounded-xl bg-white px-4 py-2.5 text-sm font-bold text-emerald-950 transition hover:bg-emerald-50"
        >Ver pedidos y atribución <.icon name="hero-arrow-up-right" class="size-4" /></.link>
      </header>
      <div id="native-sales-admin" class="border-b border-slate-200 bg-emerald-50/50 p-5 sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h3 class="font-bold text-slate-950">Ventas por WhatsApp</h3><p class="mt-1 max-w-3xl text-sm leading-6 text-slate-600">
              Abre la conversación y elige «Registrar pedido». Guarda los productos, la entrega y el pago por transferencia o contraentrega. Estos pedidos se gestionan en el CRM y no requieren Shopify.
            </p>
          </div><.link
            id="admin-register-native-order"
            navigate={~p"/crm"}
            class="rounded-xl bg-emerald-950 px-4 py-3 text-sm font-bold text-white hover:bg-emerald-800"
          >Abrir conversaciones</.link>
        </div>
        <div class="mt-4 grid gap-3 sm:grid-cols-3">
          <div class="rounded-xl bg-white p-4">
            <p class="text-xs text-slate-500">Pedidos de WhatsApp</p><p
              id="admin-native-orders"
              class="mt-1 text-2xl font-bold"
            >
              {@status.native_orders}
            </p>
          </div><div class="rounded-xl bg-white p-4">
            <p class="text-xs text-slate-500">Transferencias pendientes</p><p
              id="admin-native-transfer-pending"
              class="mt-1 text-2xl font-bold"
            >
              {@status.native_transfer_pending}
            </p>
          </div><div class="rounded-xl bg-white p-4">
            <p class="text-xs text-slate-500">Contraentregas por recaudar</p><p
              id="admin-native-cod-pending"
              class="mt-1 text-2xl font-bold"
            >
              {@status.native_cod_pending}
            </p>
          </div>
        </div>
      </div>
      <div class="grid gap-6 p-5 sm:p-6 xl:grid-cols-2">
        <div class="space-y-5">
          <div>
            <h3 class="font-bold text-slate-950">Canal Shopify y campañas (opcional)</h3><p class="mt-1 text-sm leading-6 text-slate-500">
              Shopify envía los cambios de los pedidos vendidos por ese canal. El CRM los relaciona con el cliente y muestra la evidencia disponible.
            </p>
          </div>
          <.form
            for={@form}
            id="order-integration-form"
            phx-change="validate_integration"
            phx-submit="save_integration"
            class="space-y-4"
          >
            <.input
              class="block w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
              field={@form[:shopify_shop_domain]}
              label="Dominio de la tienda Shopify"
              placeholder="tienda.myshopify.com"
            />
            <.input
              class="block w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
              field={@form[:whatsapp_number]}
              label="WhatsApp para enlaces de campañas"
              placeholder="+57 300 123 4567"
            />
            <p class="text-xs leading-5 text-slate-500">
              Usa el número conectado a Meta Cloud API. Los mensajes enviados a un número fuera del CRM no podrán asociarse a la campaña.
            </p>
            <details class="rounded-2xl border border-slate-200 p-4">
              <summary class="cursor-pointer text-sm font-semibold text-slate-700">
                Nombres de métodos de pago en Shopify
              </summary><div class="mt-4 space-y-4">
                <p class="text-xs leading-5 text-slate-500">
                  Transferencia bancaria, Mercado Pago y contraentrega ya se reconocen por sus nombres habituales. Si Shopify usa otros nombres, escríbelos aquí separados por comas. La transportadora TCC se toma de los datos de envío.
                </p>
                <.input
                  class="block w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
                  field={@form[:bank_transfer]}
                  label="Transferencia bancaria"
                  placeholder="Transferencia Bancolombia"
                />
                <.input
                  class="block w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
                  field={@form[:mercado_pago_shopify]}
                  label="Mercado Pago en Shopify"
                  placeholder="Mi pasarela Mercado Pago"
                />
                <.input
                  class="block w-full min-w-0 rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
                  field={@form[:collect_on_delivery]}
                  label="Pago contraentrega"
                  placeholder="Recaudo TCC"
                />
              </div>
            </details>
            <button
              id="save-order-integration"
              phx-disable-with="Guardando…"
              class="w-full rounded-xl bg-emerald-950 px-4 py-3 text-sm font-bold text-white transition hover:bg-emerald-800"
            >Guardar conexión</button>
          </.form>
          <div
            id="shopify-secret-status"
            data-ready={to_string(@secret_ready)}
            class="rounded-2xl bg-slate-50 p-4 text-sm"
          >
            <p class="font-semibold text-slate-800">
              Firma del canal Shopify: {if @secret_ready,
                do: "secreto configurado",
                else: "falta configurar el secreto"}
            </p>
            <p class="mt-1 text-xs leading-5 text-slate-500">
              El responsable del despliegue debe configurar <code>SHOPIFY_WEBHOOK_SECRET</code>
              y reiniciar la aplicación. Su valor permanece oculto. Tener el secreto configurado no confirma que Shopify esté enviando eventos.
            </p>
          </div>
        </div>
        <div class="space-y-5">
          <div>
            <h3 class="font-bold text-slate-950">Avisos del canal Shopify</h3><p class="mt-1 text-sm leading-6 text-slate-500">
              Configura las notificaciones de pedidos de tu tienda para enviar eventos JSON a esta dirección. Guardar el dominio aquí no crea esas suscripciones.
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 p-4">
            <p class="text-xs font-semibold text-slate-500">Dirección de recepción</p><code
              id="shopify-webhook-url"
              class="mt-2 block break-all text-sm text-emerald-800"
            >{@base_url}/webhooks/shopify</code><p class="mt-2 text-xs leading-5 text-slate-500">
              Usa el dominio público HTTPS de esta aplicación. Si estás viendo localhost, abre primero la dirección pública para obtener el enlace correcto.
            </p>
          </div>
          <div class="rounded-2xl bg-slate-50 p-4 text-xs leading-6 text-slate-600">
            <p class="font-semibold text-slate-800">Notificaciones necesarias</p><p>
              Creación, actualización, pago, cancelación, despacho completo y reembolso.
            </p><details class="mt-2">
              <summary class="cursor-pointer font-medium">
                Nombres para configurar la integración
              </summary><code class="block break-words">orders/create · orders/updated · orders/paid · orders/cancelled · orders/fulfilled · refunds/create</code>
            </details>
          </div>
          <div>
            <h3 class="font-bold text-slate-950">Conecta la adquisición de WhatsApp</h3><p class="mt-2 text-sm leading-6 text-slate-500">
              <strong class="text-slate-700">Instagram / Meta:</strong>
              la referencia del anuncio se captura cuando Meta la incluye en un mensaje entrante de WhatsApp. No hace falta pegar un identificador de campaña en el pedido.
            </p><p class="mt-2 text-sm leading-6 text-slate-500">
              <strong class="text-slate-700">Google:</strong>
              usa el enlace de abajo como destino de la campaña y añade sus parámetros UTM. El cliente debe enviar el mensaje prellenado con su código para conectar la visita con la conversación.
            </p>
          </div>
          <div id="google-tracking-link" class="rounded-2xl border border-slate-200 p-4">
            <code
              :if={@store.agent_limits["acquisition_whatsapp_number"]}
              class="block break-all text-sm text-emerald-800"
            >{@base_url}{~p"/r/#{@store.slug}/google"}?utm_source=google&amp;utm_medium=cpc&amp;utm_campaign=nombre_de_campana</code><p
              :if={!@store.agent_limits["acquisition_whatsapp_number"]}
              class="text-sm text-amber-800"
            >
              Guarda el número de WhatsApp para habilitar el enlace de campaña.
            </p><p class="mt-2 text-xs leading-5 text-slate-500">
              El código dura una hora. Una compra sin evidencia de campaña permanece como adquisición desconocida.
            </p>
          </div>
        </div>
      </div>
      <div class="border-t border-slate-200 bg-slate-50/70 p-5 sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 class="font-bold text-slate-950">Comprueba qué está llegando</h3><p class="mt-1 text-xs text-slate-500">
              Guardar la configuración no importa pedidos anteriores. Aquí se muestran los eventos recibidos por esta tienda.
            </p>
          </div><button
            id="refresh-order-integration"
            phx-click="refresh_integration"
            class="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold text-slate-700 transition hover:bg-slate-100"
          ><.icon name="hero-arrow-path" class="size-4" /> Actualizar estado</button>
        </div>
        <div class="mt-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <div class="rounded-2xl border border-slate-200 bg-white p-4">
            <p class="text-xs text-slate-500">Eventos procesados</p><p
              id="integration-processed"
              class="mt-1 text-2xl font-bold text-slate-950"
            >
              {@status.processed}
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4">
            <p class="text-xs text-slate-500">Pendientes / con error</p><p class="mt-1 text-2xl font-bold text-slate-950">
              <span id="integration-pending">{@status.pending}</span>
              / <span id="integration-failed">{@status.failed}</span>
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4">
            <p class="text-xs text-slate-500">Pedidos / por conciliar</p><p class="mt-1 text-2xl font-bold text-slate-950">
              <span id="integration-orders">{@status.orders}</span>
              / <span id="integration-review">{@status.review}</span>
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4">
            <p class="text-xs text-slate-500">Referencias Meta</p><p
              id="integration-meta"
              class="mt-1 text-2xl font-bold text-slate-950"
            >
              {@status.meta}
            </p>
          </div>
        </div>
        <div class="mt-4 flex flex-wrap justify-between gap-3 text-xs text-slate-600">
          <p>
            Google: <strong id="integration-google-visits">{@status.google_visits}</strong>
            visitas registradas ·
            <strong id="integration-google-resolved">{@status.google_resolved}</strong>
            asociadas a clientes
          </p><p id="integration-last-received">
            Última recepción: {if @status.last_received_at,
              do: Calendar.strftime(@status.last_received_at, "%Y-%m-%d %H:%M UTC"),
              else: "sin eventos recibidos"}
          </p>
        </div>
        <div id="shopify-event-monitor" phx-update="stream" class="mt-5 space-y-2">
          <p
            id="shopify-events-empty"
            class="hidden rounded-2xl border border-dashed border-slate-300 p-5 text-sm leading-6 text-slate-500 only:block"
          >
            Todavía no recibimos eventos de Shopify. Después de configurar las notificaciones, envía un evento de prueba desde Shopify y actualiza este panel. Una firma rechazada no se guarda como evento.
          </p>
          <article
            :for={{id, event} <- @events}
            id={id}
            class="rounded-xl border border-slate-200 bg-white p-4"
          >
            <div class="flex flex-wrap justify-between gap-2">
              <p class="text-sm font-semibold text-slate-800">
                {event.topic} · Pedido {event.order_id}
              </p><span class={[
                "rounded-full px-2 py-1 text-xs font-semibold",
                event.status == "processed" && "bg-emerald-50 text-emerald-800",
                event.status != "processed" && "bg-amber-50 text-amber-800"
              ]}>{event_status(event.status)}</span>
            </div>
            <p class="mt-2 break-all text-xs text-slate-500">
              {event.external_id} · {Calendar.strftime(event.inserted_at, "%Y-%m-%d %H:%M UTC")}
            </p>
            <p :if={event.status == "failed"} class="mt-2 text-xs text-amber-800">
              {failure_reason(event.error)}
            </p>
          </article>
        </div>
        <p class="mt-3 text-xs text-slate-500">
          Últimos 20 eventos. Para ver compras, atribución y seguimientos de entrega, abre «Ver pedidos y atribución».
        </p>
      </div>
    </section>
    """
  end

  defp event_status("processed"), do: "Procesado"
  defp event_status("failed"), do: "Con error"
  defp event_status(_), do: "Pendiente"

  defp failure_reason(":awaiting_order_snapshot"),
    do:
      "El reembolso llegó antes que el pedido. Hace falta recibir el evento del pedido para completar la actualización."

  defp failure_reason(_),
    do:
      "No se pudo procesar el evento. Revisa el envío en Shopify y comparte el identificador del evento con soporte."
end
