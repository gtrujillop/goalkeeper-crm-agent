defmodule StoreCRM.Repo.Migrations.AddWhatsappMessaging do
  use Ecto.Migration

  def change do
    create table(:whatsapp_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :phone_number_id, :string, null: false
      add :business_account_id, :string, null: false
      add :locale_templates, :map, null: false, default: %{}
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:whatsapp_accounts, [:phone_number_id])
    create index(:whatsapp_accounts, [:store_profile_id])

    create table(:whatsapp_webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :whatsapp_account_id,
          references(:whatsapp_accounts, type: :binary_id, on_delete: :delete_all),
          null: false

      add :external_id, :string, null: false
      add :kind, :string, null: false
      add :payload, :map, null: false
      add :status, :string, null: false, default: "accepted"
      add :error, :text
      add :processed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:whatsapp_webhook_events, [:whatsapp_account_id, :external_id, :kind])
    create index(:whatsapp_webhook_events, [:store_profile_id, :status])

    create table(:message_delivery_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all),
        null: false

      add :status, :string, null: false
      add :provider_event_id, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :details, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create unique_index(:message_delivery_events, [:message_id, :provider_event_id, :status])
    create index(:message_delivery_events, [:store_profile_id, :message_id, :occurred_at])
  end
end
