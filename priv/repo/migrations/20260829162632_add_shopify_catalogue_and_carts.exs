defmodule StoreCRM.Repo.Migrations.AddShopifyCatalogueAndCarts do
  use Ecto.Migration

  def change do
    alter table(:store_profiles) do
      add :shopify_shop_domain, :string
      add :shopify_api_version, :string
    end

    create table(:commerce_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :store_profile_id,
          references(:store_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :provider, :string, null: false
      add :external_cart_id, :string, null: false
      add :checkout_url, :text, null: false
      add :currency, :string, null: false
      add :status, :string, null: false, default: "open"
      add :raw_payload, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create unique_index(:commerce_sessions, [:store_profile_id, :provider, :external_cart_id])
    create index(:commerce_sessions, [:store_profile_id, :customer_id, :conversation_id])
  end
end
