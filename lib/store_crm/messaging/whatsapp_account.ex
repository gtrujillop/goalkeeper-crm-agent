defmodule StoreCRM.Messaging.WhatsAppAccount do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "whatsapp_accounts" do
    field :phone_number_id, :string
    field :business_account_id, :string
    field :locale_templates, :map, default: %{}
    field :active, :boolean, default: true
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    timestamps(type: :utc_datetime)
  end

  def changeset(account, attrs),
    do:
      account
      |> cast(attrs, [:phone_number_id, :business_account_id, :locale_templates, :active])
      |> validate_required([:phone_number_id, :business_account_id])
      |> unique_constraint(:phone_number_id)
end
