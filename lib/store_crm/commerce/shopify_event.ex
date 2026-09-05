defmodule StoreCRM.Commerce.ShopifyEvent do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shopify_events" do
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    field :external_id, :string
    field :order_id, :string
    field :topic, :string
    field :payload, :map
    field :status, :string, default: "pending"
    field :error, :string
    field :occurred_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
