defmodule StoreCRM.CRM.OrderSummary do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "order_summaries" do
    field :native_request_id, Ecto.UUID
    field :lock_version, :integer, default: 1
    field :shopify_order_id, :string
    field :order_name, :string
    field :status, :string
    field :total, :decimal
    field :currency, :string
    field :shopify_admin_url, :string
    field :placed_at, :utc_datetime
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    belongs_to :opportunity, StoreCRM.CRM.Opportunity
    field :financial_status, :string, default: "unknown"
    field :fulfillment_status, :string, default: "unfulfilled"
    field :payment_path, :string, default: "unknown"
    field :carrier, :string
    field :order_channel, :string, default: "direct_shopify"
    field :identity_evidence, :map, default: %{}
    field :reconciliation_required, :boolean, default: false
    field :snapshot, :map, default: %{}
    field :refunded_total, :decimal, default: Decimal.new(0)
    field :paid_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :last_synced_at, :utc_datetime
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
