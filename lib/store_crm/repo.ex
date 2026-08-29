defmodule StoreCRM.Repo do
  use Ecto.Repo,
    otp_app: :store_crm,
    adapter: Ecto.Adapters.Postgres
end
