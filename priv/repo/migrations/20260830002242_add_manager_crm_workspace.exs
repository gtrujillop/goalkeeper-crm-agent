defmodule StoreCRM.Repo.Migrations.AddManagerCrmWorkspace do
  use Ecto.Migration

  def change do
    alter table(:customers) do
      add :name, :string
      add :email, :string
      add :profile_confidence, :string, null: false, default: "unconfirmed"
    end

    alter table(:conversations) do
      add :assigned_to, :string
      add :automation_enabled, :boolean, null: false, default: true
    end

    create table(:crm_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all)
      add :body, :text, null: false
      add :author, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:crm_notes, [:store_profile_id, :customer_id])

    create table(:follow_up_tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all)
      add :title, :string, null: false
      add :due_at, :utc_datetime
      add :status, :string, null: false, default: "open"
      timestamps(type: :utc_datetime)
    end

    create index(:follow_up_tasks, [:store_profile_id, :customer_id, :status])

    create table(:opportunities, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :title, :string, null: false
      add :stage, :string, null: false, default: "new"
      add :amount, :decimal
      add :currency, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:opportunities, [:store_profile_id, :stage])

    create table(:order_summaries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :shopify_order_id, :string, null: false
      add :order_name, :string, null: false
      add :status, :string, null: false
      add :total, :decimal, null: false
      add :currency, :string, null: false
      add :shopify_admin_url, :string, null: false
      add :placed_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:order_summaries, [:store_profile_id, :shopify_order_id])
  end
end
