defmodule StoreCRMWeb.ShopifyLive do
  use StoreCRMWeb, :live_view

  alias StoreCRM.Catalogue.Shopify
  alias StoreCRM.{Commerce, Conversations, Stores}

  @impl true
  def mount(_params, _session, socket) do
    store = Stores.get_profile_by_slug!("colombia")

    {:ok,
     socket
     |> assign(:store, store)
     |> assign(:form, to_form(%{"query" => ""}, as: :catalogue))
     |> assign(:configured?, configured?())
     |> assign(:search_error, nil)
     |> assign(:variants, %{})
     |> assign(:cart, nil)
     |> stream_configure(:products, dom_id: &product_dom_id/1)
     |> stream(:products, [])}
  end

  @impl true
  def handle_event("search", %{"catalogue" => %{"query" => query}}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply, assign(socket, :search_error, "Ingresa un nombre o una palabra clave.")}
    else
      case adapter().execute(
             "search_products",
             %{"query" => query},
             context(socket.assigns.store)
           ) do
        {:ok, %{"products" => products}} ->
          variants =
            for product <- products,
                variant <- product["purchasable_variants"],
                into: %{},
                do: {variant["id"], %{variant: variant, product: product}}

          {:noreply,
           socket
           |> assign(:form, to_form(%{"query" => query}, as: :catalogue))
           |> assign(:search_error, nil)
           |> assign(:variants, variants)
           |> assign(:cart, nil)
           |> stream(:products, products, reset: true)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, commerce_error(reason))}
      end
    end
  end

  def handle_event("create_cart", %{"variant_id" => variant_id}, socket) do
    case Map.fetch(socket.assigns.variants, variant_id) do
      {:ok, item} ->
        create_cart(socket, item)

      :error ->
        {:noreply,
         put_flash(socket, :error, "Esa variante ya no está disponible. Busca nuevamente.")}
    end
  end

  defp create_cart(socket, %{product: product, variant: variant}) do
    store = socket.assigns.store

    with {:ok, ingestion} <- Conversations.ingest(store, test_inbound()),
         cart_context =
           Map.merge(context(store), %{
             customer_id: ingestion.customer.id,
             conversation_id: ingestion.conversation.id
           }),
         {:ok, cart} <-
           adapter().execute(
             "create_cart",
             %{"lines" => [%{"merchandiseId" => variant["id"], "quantity" => 1}]},
             cart_context
           ),
         {:ok, session} <- Commerce.record_cart(cart_context, cart) do
      {:noreply,
       socket
       |> assign(:cart, %{session: session, product: product, variant: variant})
       |> put_flash(:info, "El carrito de prueba fue creado y asociado con la conversación.")}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, commerce_error(reason))}
    end
  end

  defp context(store),
    do: %{
      store_profile_id: store.id,
      market: store.market,
      locale: store.default_locale,
      currency: store.currency,
      timezone: store.timezone
    }

  defp test_inbound,
    do: %{
      source: "shopify_workspace",
      provider_message_id: "workspace-#{Ecto.UUID.generate()}",
      phone: "3000000000",
      content: "Operator-created Shopify test cart",
      raw_payload: %{"test" => true}
    }

  defp configured? do
    Enum.all?(["SHOPIFY_SHOP_DOMAIN", "SHOPIFY_STOREFRONT_PRIVATE_TOKEN"], fn key ->
      case System.get_env(key) do
        value when is_binary(value) -> String.trim(value) != ""
        _ -> false
      end
    end)
  end

  defp adapter, do: Application.get_env(:store_crm, :catalogue_adapter, Shopify)
  defp product_dom_id(product), do: "product-#{:erlang.phash2(product["id"])}"

  defp commerce_error(:shopify_not_configured),
    do: "Las credenciales de Shopify no están configuradas."

  defp commerce_error(_reason),
    do: "Shopify no pudo completar la solicitud. Intenta nuevamente o solicita ayuda humana."

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="shopify-workspace" class="space-y-6">
        <header class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.2em] text-emerald-700">
              Comercio en vivo
            </p>
            <h1 class="mt-2 text-3xl font-bold tracking-tight text-slate-950 sm:text-4xl">
              Espacio de Shopify
            </h1>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              Busca en el catálogo, confirma las variantes disponibles y crea una ruta de pago de prueba trazable.
            </p>
          </div>
          <div
            id="shopify-connection-status"
            class={[
              "inline-flex w-fit items-center gap-2 rounded-full px-3 py-2 text-xs font-bold ring-1",
              if(@configured?,
                do: "bg-emerald-50 text-emerald-800 ring-emerald-200",
                else: "bg-amber-50 text-amber-800 ring-amber-200"
              )
            ]}
          >
            <span class={[
              "size-2 rounded-full",
              if(@configured?, do: "bg-emerald-500", else: "bg-amber-500")
            ]}></span>
            {if(@configured?, do: "Conexión privada configurada", else: "Configuración requerida")}
          </div>
        </header>

        <section class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <.form
            for={@form}
            id="catalogue-search-form"
            phx-submit="search"
            class="space-y-3"
          >
            <label for="catalogue_query" class="block text-sm font-bold text-slate-900">Buscar un producto de Shopify</label>
            <div class="flex flex-col gap-3 sm:flex-row">
              <div class="relative flex-1">
                <.icon
                  name="hero-magnifying-glass"
                  class="pointer-events-none absolute left-4 top-1/2 size-5 -translate-y-1/2 text-slate-400"
                />
                <.input
                  field={@form[:query]}
                  type="search"
                  aria-label="Buscar un producto de Shopify"
                  placeholder="Ej. DEL003 Test Gloves"
                  autocomplete="off"
                  class="h-12 w-full rounded-2xl border border-slate-300 bg-white pl-12 pr-4 text-base text-slate-950 outline-none transition placeholder:text-slate-400 focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100"
                />
              </div>
              <button
                id="catalogue-search-button"
                type="submit"
                class="inline-flex h-12 items-center justify-center gap-2 rounded-2xl bg-emerald-950 px-6 text-sm font-bold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-emerald-800 focus:outline-none focus:ring-4 focus:ring-emerald-200"
              ><.icon name="hero-magnifying-glass" class="size-4" /> Buscar</button>
            </div>
            <p
              :if={@search_error}
              id="catalogue-search-error"
              class="flex items-center gap-2 text-sm font-semibold text-red-700"
            >
              <.icon name="hero-exclamation-circle" class="size-4" /> {@search_error}
            </p>
          </.form>
        </section>

        <div id="catalogue-products" phx-update="stream" class="grid gap-4 lg:grid-cols-2">
          <div
            id="catalogue-empty-state"
            class="hidden only:block rounded-3xl border border-dashed border-slate-300 bg-slate-50 px-6 py-14 text-center lg:col-span-2"
          >
            <.icon name="hero-shopping-bag" class="mx-auto size-8 text-slate-400" /><p class="mt-3 text-sm font-semibold text-slate-700">
              Busca para consultar el catálogo en vivo de Shopify.
            </p>
          </div>
          <article
            :for={{id, product} <- @streams.products}
            id={id}
            class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="text-xs font-bold uppercase tracking-wider text-emerald-700">
                  Producto de Shopify
                </p><h2 class="mt-1 text-xl font-bold text-slate-950">{product["title"]}</h2>
              </div>
              <a
                :if={product["url"]}
                href={product["url"]}
                target="_blank"
                rel="noreferrer"
                class="rounded-xl p-2 text-slate-500 transition hover:bg-slate-100 hover:text-slate-950"
                aria-label="Abrir producto en Shopify"
              ><.icon name="hero-arrow-top-right-on-square" class="size-5" /></a>
            </div>
            <div class="mt-5 space-y-3">
              <div
                :for={variant <- product["variants"]}
                id={"variant-#{variant["id"]}"}
                class="flex items-center justify-between gap-4 rounded-2xl bg-slate-50 p-4"
              >
                <div>
                  <p class="text-sm font-bold text-slate-900">{variant["title"]}</p><p class="mt-1 text-sm text-slate-600">
                    {variant["display_price"] || "#{variant["price"]} #{variant["currency"]}"}
                  </p>
                </div>
                <button
                  :if={variant["available"]}
                  id={"create-cart-#{variant["id"]}"}
                  phx-click="create_cart"
                  phx-value-variant_id={variant["id"]}
                  class="rounded-xl bg-lime-300 px-4 py-2 text-xs font-bold text-emerald-950 transition hover:bg-lime-200"
                >Crear carrito de prueba</button>
                <span
                  :if={!variant["available"]}
                  class="rounded-full bg-slate-200 px-3 py-1 text-xs font-bold text-slate-600"
                >No disponible</span>
              </div>
            </div>
          </article>
        </div>

        <section
          :if={@cart}
          id="cart-result"
          class="rounded-3xl border border-emerald-200 bg-emerald-50 p-6 shadow-sm"
        >
          <div class="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p class="flex items-center gap-2 text-sm font-bold text-emerald-900">
                <.icon name="hero-check-circle" class="size-5" /> Carrito creado y trazado
              </p><p class="mt-2 text-sm text-emerald-800">
                {@cart.product["title"]} · {@cart.variant["title"]} · {@cart.session.currency}
              </p><p class="mt-1 text-xs text-emerald-700">No se ha enviado ningún pedido ni pago.</p>
            </div>
            <a
              id="open-test-checkout"
              href={@cart.session.checkout_url}
              target="_blank"
              rel="noreferrer"
              class="inline-flex items-center justify-center gap-2 rounded-xl bg-emerald-950 px-5 py-3 text-sm font-bold text-white transition hover:bg-emerald-800"
            >Abrir pago <.icon name="hero-arrow-top-right-on-square" class="size-4" /></a>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
