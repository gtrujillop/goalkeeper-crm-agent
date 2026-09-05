defmodule StoreCRM.CRM.Opportunity do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "opportunities" do
    field :title, :string
    field :stage, :string, default: "new"
    field :amount, :decimal
    field :currency, :string
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    timestamps(type: :utc_datetime)
  end

  def changeset(opportunity, attrs),
    do:
      opportunity
      |> cast(attrs, [:title, :stage, :amount, :currency])
      |> validate_required([:title, :stage, :currency])
      |> validate_inclusion(:stage, ~w(new qualified checkout won lost))
end
