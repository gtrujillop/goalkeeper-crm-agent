defmodule StoreCRM.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :direction, :string
    field :source, :string
    field :provider_message_id, :string
    field :content, :string
    field :content_type, :string, default: "text"
    field :status, :string
    field :position, :integer
    field :occurred_at, :utc_datetime
    field :raw_payload, :map, default: %{}
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs),
    do:
      message
      |> cast(attrs, [
        :direction,
        :source,
        :provider_message_id,
        :content,
        :content_type,
        :status,
        :position,
        :occurred_at,
        :raw_payload
      ])
      |> validate_required([
        :direction,
        :source,
        :provider_message_id,
        :content,
        :status,
        :position,
        :occurred_at
      ])
      |> validate_inclusion(:direction, ~w(inbound outbound))
      |> unique_constraint([:store_profile_id, :source, :provider_message_id])
end
