defmodule StoreCRM.Commerce.IntegrationSettings do
  use Ecto.Schema
  import Ecto.Changeset, except: [change: 1, change: 2]
  import Ecto.Query
  alias StoreCRM.{Repo, Stores}
  @primary_key false
  embedded_schema do
    field :shopify_shop_domain, :string
    field :whatsapp_number, :string
    field :bank_transfer, :string
    field :mercado_pago_shopify, :string
    field :collect_on_delivery, :string
  end

  @paths [:bank_transfer, :mercado_pago_shopify, :collect_on_delivery]

  def change(store, attrs \\ %{}) do
    mappings = store.agent_limits["payment_paths"] || %{}

    values =
      Enum.map(@paths, fn path ->
        names = for {name, value} <- mappings, value == Atom.to_string(path), do: name
        {path, names |> Enum.sort() |> Enum.join(", ")}
      end)

    struct!(
      __MODULE__,
      values ++
        [
          shopify_shop_domain: store.shopify_shop_domain,
          whatsapp_number: store.agent_limits["acquisition_whatsapp_number"]
        ]
    )
    |> cast(attrs, [:shopify_shop_domain, :whatsapp_number | @paths])
    |> update_change(:shopify_shop_domain, &normalize_domain/1)
    |> update_change(:whatsapp_number, &normalize_phone/1)
    |> validate_format(:shopify_shop_domain, ~r/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/,
      message: "Usa el dominio tienda.myshopify.com, sin https:// ni rutas"
    )
    |> validate_format(:whatsapp_number, ~r/^[1-9]\d{7,14}$/,
      message: "Incluye el indicativo del país, por ejemplo +57 300 123 4567"
    )
    |> validate_length(:shopify_shop_domain, max: 253)
    |> validate_length(:bank_transfer, max: 500)
    |> validate_length(:mercado_pago_shopify, max: 500)
    |> validate_length(:collect_on_delivery, max: 500)
    |> validate_mapping_conflicts()
    |> validate_domain_owner(store)
  end

  def save(store, attrs) do
    store = Stores.get_profile!(store.id)
    changeset = change(store, attrs)

    with {:ok, settings} <- apply_action(changeset, :update) do
      paths = Enum.map(@paths, &Atom.to_string/1)

      retained =
        Map.reject(store.agent_limits["payment_paths"] || %{}, fn {_, path} -> path in paths end)

      mappings =
        Enum.reduce(@paths, retained, fn path, acc ->
          Enum.reduce(names(Map.get(settings, path)), acc, &Map.put(&2, &1, Atom.to_string(path)))
        end)

      limits =
        store.agent_limits
        |> Map.put("acquisition_whatsapp_number", settings.whatsapp_number)
        |> Map.put("payment_paths", mappings)

      Stores.update_profile(store, %{
        shopify_shop_domain: settings.shopify_shop_domain,
        agent_limits: limits
      })
    end
  end

  defp validate_mapping_conflicts(changeset) do
    all = Enum.flat_map(@paths, &names(get_field(changeset, &1)))

    if length(all) == length(Enum.uniq(all)),
      do: changeset,
      else:
        add_error(
          changeset,
          :bank_transfer,
          "Cada nombre de pago debe pertenecer a una sola categoría"
        )
  end

  defp validate_domain_owner(changeset, store) do
    domain = get_field(changeset, :shopify_shop_domain)

    if domain &&
         Repo.exists?(
           from s in Stores.StoreProfile,
             where: s.shopify_shop_domain == ^domain and s.id != ^store.id
         ),
       do: add_error(changeset, :shopify_shop_domain, "Este dominio ya pertenece a otra tienda"),
       else: changeset
  end

  defp normalize_domain(nil), do: nil
  defp normalize_domain(value), do: value |> String.trim() |> String.downcase()
  defp normalize_phone(nil), do: nil
  defp normalize_phone(value), do: value |> String.trim() |> String.replace(~r/[+\s()-]/, "")

  defp names(value),
    do:
      (value || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.downcase(String.trim(&1)))
      |> Enum.reject(&(&1 == ""))
end
