defmodule StoreCRM.Repo.Migrations.AddNativeWhatsappOrders do
  use Ecto.Migration

  def up do
    alter table(:order_summaries) do
      modify :shopify_order_id, :string, null: true
      modify :shopify_admin_url, :string, null: true
      add :native_request_id, :uuid
      add :lock_version, :integer, null: false, default: 1
    end

    create unique_index(:order_summaries, [:store_profile_id, :native_request_id])

    create constraint(:order_summaries, :order_channel_reference,
             check:
               "(order_channel = 'whatsapp' AND native_request_id IS NOT NULL AND shopify_order_id IS NULL AND shopify_admin_url IS NULL) OR (order_channel <> 'whatsapp' AND shopify_order_id IS NOT NULL AND shopify_admin_url IS NOT NULL)"
           )

    create table(:native_order_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :store_profile_id, references(:store_profiles, type: :binary_id), null: false
      add :order_summary_id, references(:order_summaries, type: :binary_id), null: false
      add :order_version, :integer, null: false
      add :actor, :string, null: false
      add :kind, :string, null: false
      add :evidence, :map, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:native_order_events, [
             :store_profile_id,
             :order_summary_id,
             :order_version
           ])
  end

  def down do
    drop table(:native_order_events)
    drop constraint(:order_summaries, :order_channel_reference)
    drop unique_index(:order_summaries, [:store_profile_id, :native_request_id])

    alter table(:order_summaries) do
      remove :native_request_id
      remove :lock_version
      # Restoring these constraints requires migrating native orders first.
      modify :shopify_order_id, :string, null: false
      modify :shopify_admin_url, :string, null: false
    end
  end
end
