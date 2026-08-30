defmodule StoreCRM.CRM.OrderSummary do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "order_summaries" do
    field :shopify_order_id, :string
    field :order_name, :string
    field :status, :string
    field :total, :decimal
    field :currency, :string
    field :shopify_admin_url, :string
    field :placed_at, :utc_datetime
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs),
    do:
      order
      |> cast(attrs, [
        :shopify_order_id,
        :order_name,
        :status,
        :total,
        :currency,
        :shopify_admin_url,
        :placed_at
      ])
      |> validate_required([
        :shopify_order_id,
        :order_name,
        :status,
        :total,
        :currency,
        :shopify_admin_url,
        :placed_at
      ])
      |> validate_format(:shopify_admin_url, ~r/^https:\/\//)
      |> unique_constraint([:store_profile_id, :shopify_order_id])
end
