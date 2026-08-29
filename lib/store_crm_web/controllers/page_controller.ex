defmodule StoreCRMWeb.PageController do
  use StoreCRMWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
