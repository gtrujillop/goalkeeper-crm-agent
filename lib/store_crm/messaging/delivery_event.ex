defmodule StoreCRM.Messaging.DeliveryEvent do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "message_delivery_events" do
    field :status, :string
    field :provider_event_id, :string
    field :occurred_at, :utc_datetime
    field :details, :map, default: %{}
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :message, StoreCRM.Conversations.Message
    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs),
    do:
      event
      |> cast(attrs, [:status, :provider_event_id, :occurred_at, :details])
      |> validate_required([:status, :provider_event_id, :occurred_at])
      |> unique_constraint([:message_id, :provider_event_id, :status])
end
