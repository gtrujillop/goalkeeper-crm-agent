defmodule StoreCRM.Customers.Identity do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "customer_identities" do
    field :provider, :string
    field :external_id, :string
    field :normalized_value, :string
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    timestamps(type: :utc_datetime)
  end

  def changeset(identity, attrs),
    do:
      identity
      |> cast(attrs, [:provider, :external_id, :normalized_value])
      |> validate_required([:provider, :external_id, :normalized_value])
end
