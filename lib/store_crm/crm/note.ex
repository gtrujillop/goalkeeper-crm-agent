defmodule StoreCRM.CRM.Note do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "crm_notes" do
    field :body, :string
    field :author, :string
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs),
    do: note |> cast(attrs, [:body, :author]) |> validate_required([:body, :author])
end
