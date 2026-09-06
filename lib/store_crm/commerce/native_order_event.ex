defmodule StoreCRM.Commerce.NativeOrderEvent do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "native_order_events" do
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :order_summary, StoreCRM.CRM.OrderSummary
    field :order_version, :integer
    field :actor, :string
    field :kind, :string
    field :evidence, :map
    timestamps(type: :utc_datetime)
  end
end
