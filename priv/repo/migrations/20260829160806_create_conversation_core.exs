defmodule StoreCRM.Repo.Migrations.CreateConversationCore do
  use Ecto.Migration

  def change do
    create table(:store_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :market, :string, null: false
      add :default_locale, :string, null: false
      add :currency, :string, null: false
      add :timezone, :string, null: false
      add :phone_region, :string, null: false
      add :enabled_locales, {:array, :string}, null: false, default: []
      add :agent_limits, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create unique_index(:store_profiles, [:slug])

    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :preferred_locale, :string
      add :first_interaction_at, :utc_datetime, null: false
      add :last_interaction_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:customers, [:store_profile_id])

    create table(:customer_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :provider, :string, null: false
      add :external_id, :string, null: false
      add :normalized_value, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:customer_identities, [:store_profile_id, :provider, :external_id])
    create unique_index(:customer_identities, [:store_profile_id, :provider, :normalized_value])

    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :state, :string, null: false, default: "active"
      add :locale, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:store_profile_id, :customer_id, :state])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :direction, :string, null: false
      add :source, :string, null: false
      add :provider_message_id, :string, null: false
      add :content, :text, null: false
      add :content_type, :string, null: false, default: "text"
      add :status, :string, null: false
      add :position, :bigint, null: false
      add :occurred_at, :utc_datetime, null: false
      add :raw_payload, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create unique_index(:messages, [:store_profile_id, :source, :provider_message_id])
    create unique_index(:messages, [:conversation_id, :position])
    create index(:messages, [:store_profile_id, :conversation_id, :position])

    create table(:agent_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :input_message_id, references(:messages, type: :binary_id, on_delete: :delete_all),
        null: false

      add :output_message_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
      add :prompt_version, :string, null: false
      add :prompt, :text, null: false
      add :provider, :string, null: false
      add :model, :string, null: false
      add :provider_request_id, :string
      add :context, :map, null: false
      add :result, :text
      add :outcome, :string, null: false
      add :input_tokens, :integer, null: false, default: 0
      add :output_tokens, :integer, null: false, default: 0
      add :estimated_cost, :decimal, null: false, default: 0
      add :iteration_count, :integer, null: false, default: 0
      add :error, :text
      timestamps(type: :utc_datetime)
    end

    create index(:agent_runs, [:store_profile_id, :conversation_id])

    create table(:tool_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :agent_run_id, references(:agent_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :arguments, :map, null: false
      add :result, :map
      add :status, :string, null: false
      add :duration_ms, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create index(:tool_calls, [:store_profile_id, :agent_run_id])

    create table(:handoffs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :agent_run_id, references(:agent_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :reason, :string, null: false
      add :summary, :text, null: false
      add :status, :string, null: false, default: "requested"
      timestamps(type: :utc_datetime)
    end

    create index(:handoffs, [:store_profile_id, :conversation_id])
  end
end
