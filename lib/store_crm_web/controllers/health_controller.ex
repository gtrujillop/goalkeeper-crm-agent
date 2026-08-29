defmodule StoreCRMWeb.HealthController do
  use StoreCRMWeb, :controller

  def live(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def ready(conn, _params) do
    case Ecto.Adapters.SQL.query(StoreCRM.Repo, "SELECT 1", []) do
      {:ok, _result} ->
        json(conn, %{status: "ready"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unavailable"})
    end
  end
end
