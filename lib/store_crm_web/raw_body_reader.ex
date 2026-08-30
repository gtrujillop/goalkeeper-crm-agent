defmodule StoreCRMWeb.RawBodyReader do
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} -> {:ok, body, append_raw_body(conn, body)}
      {:more, body, conn} -> {:more, body, append_raw_body(conn, body)}
      other -> other
    end
  end

  defp append_raw_body(conn, body) do
    Plug.Conn.assign(conn, :raw_body, (conn.assigns[:raw_body] || "") <> body)
  end
end
