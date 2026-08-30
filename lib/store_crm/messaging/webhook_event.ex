defmodule StoreCRM.Messaging.WebhookEvent do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "whatsapp_webhook_events" do
    field :external_id, :string
    field :kind, :string
    field :payload, :map
    field :status, :string, default: "accepted"
    field :error, :string
    field :processed_at, :utc_datetime
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :whatsapp_account, StoreCRM.Messaging.WhatsAppAccount
    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs),
    do:
      event
      |> cast(attrs, [:external_id, :kind, :payload, :status, :error, :processed_at])
      |> validate_required([:external_id, :kind, :payload, :status])
      |> unique_constraint([:whatsapp_account_id, :external_id, :kind])
end
