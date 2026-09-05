defmodule StoreCRM.Repo.Migrations.AddOrdersAndAttribution do
  use Ecto.Migration

  def change do
    create table(:shopify_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :store_profile_id, references(:store_profiles, type: :binary_id), null: false
      add :external_id, :string, null: false
      add :order_id, :string, null: false
      add :topic, :string, null: false
      add :payload, :map, null: false
      add :status, :string, null: false, default: "pending"
      add :error, :text
      add :occurred_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:shopify_events, [:store_profile_id, :external_id, :topic])
    create index(:shopify_events, [:store_profile_id, :order_id])

    create table(:touchpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :store_profile_id, references(:store_profiles, type: :binary_id), null: false
      add :customer_id, references(:customers, type: :binary_id)
      add :conversation_id, references(:conversations, type: :binary_id)
      add :source, :string, null: false
      add :confidence, :string, null: false
      add :evidence_key, :string, null: false
      add :evidence, :map, null: false
      add :occurred_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime
      add :resolved_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:touchpoints, [:store_profile_id, :evidence_key])
    create index(:touchpoints, [:store_profile_id, :customer_id, :occurred_at])

    alter table(:commerce_sessions) do
      add :correlation_token, :text
      add :opportunity_id, references(:opportunities, type: :binary_id)
    end

    create unique_index(:commerce_sessions, [:store_profile_id, :correlation_token])

    alter table(:order_summaries) do
      add :conversation_id, references(:conversations, type: :binary_id)
      add :opportunity_id, references(:opportunities, type: :binary_id)
      add :financial_status, :string, default: "unknown", null: false
      add :fulfillment_status, :string, default: "unfulfilled", null: false
      add :payment_path, :string, default: "unknown", null: false
      add :carrier, :string
      add :order_channel, :string, default: "direct_shopify", null: false
      add :identity_evidence, :map, default: %{}, null: false
      add :reconciliation_required, :boolean, default: false, null: false
      add :snapshot, :map, default: %{}, null: false
      add :refunded_total, :decimal, default: 0, null: false
      add :paid_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :last_synced_at, :utc_datetime
    end

    alter table(:follow_up_tasks) do
      add :order_summary_id, references(:order_summaries, type: :binary_id)
    end

    create unique_index(:follow_up_tasks, [:store_profile_id, :order_summary_id])
  end
end
