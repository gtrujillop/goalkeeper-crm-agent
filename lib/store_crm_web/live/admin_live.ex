defmodule StoreCRMWeb.AdminLive do
  use StoreCRMWeb, :live_view

  alias StoreCRM.Messaging
  alias StoreCRM.Messaging.WhatsAppAccount
  alias StoreCRM.Stores

  @impl true
  def mount(_params, _session, socket) do
    store = Stores.get_profile_by_slug!("colombia")

    {:ok,
     socket
     |> assign(:store, store)
     |> assign(:page_title, "Administración")
     |> assign(:credential_status, credential_status())
     |> assign(:account, %WhatsAppAccount{store_profile_id: store.id, active: true})
     |> assign_store_form(store)
     |> assign_account_form()
     |> load_accounts()}
  end

  @impl true
  def handle_event("new_account", _, socket) do
    account = %WhatsAppAccount{store_profile_id: socket.assigns.store.id, active: true}
    {:noreply, socket |> assign(:account, account) |> assign_account_form()}
  end

  def handle_event("edit_account", %{"id" => id}, socket) do
    account = Messaging.get_account!(socket.assigns.store, id)
    {:noreply, socket |> assign(:account, account) |> assign_account_form()}
  end

  def handle_event("validate_account", %{"whats_app_account" => attrs}, socket) do
    form =
      socket.assigns.account
      |> Messaging.change_account(attrs)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :account_form, form)}
  end

  def handle_event("save_account", %{"whats_app_account" => attrs}, socket) do
    result =
      if socket.assigns.account.id,
        do: Messaging.update_account(socket.assigns.store, socket.assigns.account.id, attrs),
        else: Messaging.create_account(socket.assigns.store, attrs)

    case result do
      {:ok, account} ->
        {:noreply,
         socket
         |> assign(:account, account)
         |> assign_account_form()
         |> load_accounts()
         |> put_flash(:info, "Cuenta de WhatsApp guardada.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :account_form, to_form(changeset))}
    end
  end

  def handle_event("validate_store", %{"store_profile" => attrs}, socket) do
    form =
      socket.assigns.store
      |> Stores.change_profile(attrs)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :store_form, form)}
  end

  def handle_event("save_store", %{"store_profile" => attrs}, socket) do
    case Stores.update_profile(socket.assigns.store, attrs) do
      {:ok, store} ->
        {:noreply,
         socket
         |> assign(:store, store)
         |> assign_store_form(store)
         |> put_flash(:info, "Configuración de la tienda guardada.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :store_form, to_form(changeset))}
    end
  end

  defp load_accounts(socket) do
    accounts = Messaging.list_accounts(socket.assigns.store)
    socket |> assign(:accounts, accounts) |> assign(:accounts_empty?, accounts == [])
  end

  defp assign_account_form(socket),
    do:
      assign(
        socket,
        :account_form,
        socket.assigns.account |> Messaging.change_account() |> to_form()
      )

  defp assign_store_form(socket, store),
    do: assign(socket, :store_form, store |> Stores.change_profile() |> to_form())

  defp credential_status do
    config = Application.get_env(:store_crm, :whatsapp, [])

    %{
      access_token: configured?(config[:access_token]),
      app_secret: configured?(config[:app_secret]),
      verify_token: configured?(config[:verify_token])
    }
  end

  defp configured?(value), do: is_binary(value) and String.trim(value) != ""

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="admin-workspace" class="space-y-6">
        <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p class="text-xs font-bold uppercase tracking-[.2em] text-emerald-700">Operación</p>
            <h1 class="mt-1 text-3xl font-bold tracking-tight text-slate-950">Administración</h1>
            <p class="mt-1 max-w-2xl text-sm text-slate-600">
              Configura los canales de WhatsApp y los datos operativos de cada tienda.
            </p>
          </div>
          <span class="inline-flex w-fit items-center gap-2 rounded-full bg-slate-100 px-3 py-2 text-xs font-bold text-slate-700">
            <.icon name="hero-building-storefront" class="size-4" /> {@store.name}
          </span>
        </header>

        <div class="grid gap-6 xl:grid-cols-[1.08fr_.92fr]">
          <section
            id="whatsapp-settings"
            class="overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm"
          >
            <div class="flex flex-col items-start gap-3 border-b border-slate-200 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="font-bold text-slate-950">Cuentas de WhatsApp</h2>
                <p class="mt-0.5 text-xs text-slate-500">Números asociados a Meta Cloud API</p>
              </div>
              <button
                id="new-whatsapp-account"
                phx-click="new_account"
                class="inline-flex items-center gap-2 rounded-xl bg-emerald-950 px-3 py-2 text-xs font-bold text-white transition hover:bg-emerald-800"
              >
                <.icon name="hero-plus" class="size-4" /> Nueva cuenta
              </button>
            </div>

            <div class="grid md:grid-cols-[15rem_1fr]">
              <div
                id="whatsapp-account-list"
                class="border-b border-slate-200 bg-slate-50/80 p-3 md:border-b-0 md:border-r"
              >
                <p
                  :if={@accounts_empty?}
                  id="accounts-empty"
                  class="rounded-xl border border-dashed border-slate-300 p-4 text-center text-xs leading-5 text-slate-500"
                >
                  Aún no hay cuentas configuradas.
                </p>
                <button
                  :for={account <- @accounts}
                  id={"account-#{account.id}"}
                  phx-click="edit_account"
                  phx-value-id={account.id}
                  class={[
                    "mb-2 block w-full rounded-xl border p-3 text-left transition",
                    @account.id == account.id && "border-emerald-300 bg-white shadow-sm",
                    @account.id != account.id &&
                      "border-transparent hover:border-slate-200 hover:bg-white"
                  ]}
                >
                  <span class="flex items-center justify-between gap-2">
                    <span class="truncate text-xs font-bold text-slate-900">{account.phone_number_id}</span>
                    <span class={[
                      "size-2 rounded-full",
                      account.active && "bg-emerald-500",
                      !account.active && "bg-slate-300"
                    ]}></span>
                  </span>
                  <span class="mt-1 block truncate text-[11px] text-slate-500">WABA {account.business_account_id}</span>
                </button>
              </div>

              <div class="p-5">
                <div class="mb-5 flex items-center gap-3 rounded-2xl bg-emerald-50 p-3 text-sm text-emerald-900 ring-1 ring-emerald-100">
                  <.icon name="hero-shield-check" class="size-5 shrink-0" />
                  <p>
                    <strong>Cloud API directa.</strong>
                    Las respuestas manuales se envían desde el CRM, sin coexistencia.
                  </p>
                </div>
                <.form
                  for={@account_form}
                  id="whatsapp-account-form"
                  phx-change="validate_account"
                  phx-submit="save_account"
                  class="space-y-4"
                >
                  <.input
                    field={@account_form[:business_account_id]}
                    label="ID de la cuenta de WhatsApp Business (WABA)"
                    placeholder="Ej. 123456789012345"
                  />
                  <.input
                    field={@account_form[:phone_number_id]}
                    label="ID del número de teléfono"
                    placeholder="Ej. 109876543210987"
                  />
                  <.input
                    field={@account_form[:active]}
                    type="checkbox"
                    label="Cuenta activa para recibir y enviar mensajes"
                  />
                  <button
                    id="save-whatsapp-account"
                    class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-emerald-950 px-4 py-3 text-sm font-bold text-white transition hover:bg-emerald-800 phx-submit-loading:opacity-60"
                  >
                    <.icon name="hero-check" class="size-4" /> Guardar cuenta
                  </button>
                </.form>
              </div>
            </div>
          </section>

          <div class="space-y-6">
            <section
              id="credential-status"
              class="rounded-3xl border border-slate-200 bg-slate-950 p-5 text-white shadow-sm"
            >
              <div class="flex items-start gap-3">
                <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-white/10">
                  <.icon name="hero-key" class="size-5 text-emerald-300" />
                </span>
                <div>
                  <h2 class="font-bold">Credenciales seguras</h2>
                  <p class="mt-1 text-xs leading-5 text-slate-400">
                    Los secretos permanecen en variables de entorno y nunca se muestran en esta página.
                  </p>
                </div>
              </div>
              <div class="mt-4 grid gap-2 sm:grid-cols-3 xl:grid-cols-1 2xl:grid-cols-3">
                <div
                  :for={
                    {label, configured} <- [
                      {"Access token", @credential_status.access_token},
                      {"App secret", @credential_status.app_secret},
                      {"Verify token", @credential_status.verify_token}
                    ]
                  }
                  class="flex items-center gap-2 rounded-xl bg-white/5 px-3 py-2 text-xs"
                >
                  <span class={[
                    "size-2 rounded-full",
                    configured && "bg-emerald-400",
                    !configured && "bg-amber-400"
                  ]}></span>
                  <span>{label}</span>
                  <span class="ml-auto text-slate-400">{if(configured, do: "Listo", else: "Falta")}</span>
                </div>
              </div>
              <div class="mt-4 rounded-xl border border-white/10 px-3 py-2.5">
                <p class="text-[10px] font-bold uppercase tracking-wider text-slate-500">
                  Webhook de Meta
                </p>
                <code class="mt-1 block text-xs text-emerald-300">/webhooks/whatsapp</code>
              </div>
            </section>

            <section
              id="store-settings"
              class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <h2 class="font-bold text-slate-950">Configuración de tienda</h2>
              <p class="mt-1 text-xs text-slate-500">
                Localización y conexión administrativa con Shopify.
              </p>
              <.form
                for={@store_form}
                id="store-settings-form"
                phx-change="validate_store"
                phx-submit="save_store"
                class="mt-5 grid gap-4 sm:grid-cols-2"
              >
                <div class="sm:col-span-2"><.input field={@store_form[:name]} label="Nombre" /></div>
                <.input field={@store_form[:default_locale]} label="Idioma" />
                <.input field={@store_form[:timezone]} label="Zona horaria" />
                <.input field={@store_form[:currency]} label="Moneda" />
                <.input field={@store_form[:phone_region]} label="Región telefónica" />
                <div class="sm:col-span-2">
                  <.input
                    field={@store_form[:shopify_shop_domain]}
                    label="Dominio de Shopify"
                    placeholder="tienda.myshopify.com"
                  />
                </div>
                <button
                  id="save-store-settings"
                  class="sm:col-span-2 rounded-xl bg-slate-900 px-4 py-3 text-sm font-bold text-white transition hover:bg-slate-700 phx-submit-loading:opacity-60"
                >Guardar configuración</button>
              </.form>
            </section>
          </div>
        </div>

        <p class="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-xs leading-5 text-amber-900">
          <strong>Antes de producción:</strong>
          esta sección debe quedar protegida por autenticación y permisos administrativos.
        </p>
      </div>
    </Layouts.app>
    """
  end
end
