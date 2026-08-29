defmodule StoreCRM.Stores.StoreProfile do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "store_profiles" do
    field :slug, :string
    field :name, :string
    field :market, :string
    field :default_locale, :string
    field :currency, :string
    field :timezone, :string
    field :phone_region, :string
    field :enabled_locales, {:array, :string}, default: []
    field :agent_limits, :map, default: %{}
    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :slug,
      :name,
      :market,
      :default_locale,
      :currency,
      :timezone,
      :phone_region,
      :enabled_locales,
      :agent_limits
    ])
    |> validate_required([
      :slug,
      :name,
      :market,
      :default_locale,
      :currency,
      :timezone,
      :phone_region
    ])
    |> unique_constraint(:slug)
  end
end
