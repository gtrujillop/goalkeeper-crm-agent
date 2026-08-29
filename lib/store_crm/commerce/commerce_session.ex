defmodule StoreCRM.Commerce.CommerceSession do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "commerce_sessions" do
    field :provider, :string
    field :external_cart_id, :string
    field :checkout_url, :string
    field :currency, :string
    field :status, :string, default: "open"
    field :raw_payload, :map, default: %{}
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:provider, :external_cart_id, :checkout_url, :currency, :status, :raw_payload])
    |> validate_required([:provider, :external_cart_id, :checkout_url, :currency, :status])
    |> unique_constraint([:store_profile_id, :provider, :external_cart_id])
  end
end
