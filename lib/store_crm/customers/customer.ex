defmodule StoreCRM.Customers.Customer do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "customers" do
    field :name, :string
    field :email, :string
    field :profile_confidence, :string, default: "unconfirmed"
    field :preferred_locale, :string
    field :first_interaction_at, :utc_datetime
    field :last_interaction_at, :utc_datetime
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    timestamps(type: :utc_datetime)
  end

  def changeset(customer, attrs),
    do:
      customer
      |> cast(attrs, [
        :name,
        :email,
        :profile_confidence,
        :preferred_locale,
        :first_interaction_at,
        :last_interaction_at
      ])
      |> validate_required([:first_interaction_at, :last_interaction_at])
      |> validate_inclusion(:profile_confidence, ~w(unconfirmed inferred confirmed))
end
