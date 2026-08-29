defmodule StoreCRM.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @states ~w(active waiting_for_customer waiting_for_human human_owned closed)

  schema "conversations" do
    field :state, :string, default: "active"
    field :locale, :string
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs),
    do:
      conversation
      |> cast(attrs, [:state, :locale])
      |> validate_required([:state, :locale])
      |> validate_inclusion(:state, @states)
end
