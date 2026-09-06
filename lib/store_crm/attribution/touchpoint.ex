defmodule StoreCRM.Attribution.Touchpoint do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "touchpoints" do
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    field :source, :string
    field :confidence, :string
    field :evidence_key, :string
    field :evidence, :map
    field :occurred_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :resolved_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
