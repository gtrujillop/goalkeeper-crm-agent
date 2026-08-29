defmodule StoreCRMWeb.HealthControllerTest do
  use StoreCRMWeb.ConnCase, async: true

  test "GET /health/live reports process liveness", %{conn: conn} do
    conn = get(conn, ~p"/health/live")

    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "GET /health/ready reports database readiness", %{conn: conn} do
    conn = get(conn, ~p"/health/ready")

    assert json_response(conn, 200) == %{"status" => "ready"}
  end
end
