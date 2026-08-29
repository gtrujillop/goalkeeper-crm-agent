defmodule StoreCRM.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        StoreCRMWeb.Telemetry,
        StoreCRM.Repo,
        {DNSCluster, query: Application.get_env(:store_crm, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: StoreCRM.PubSub},
        # Start a worker by calling: StoreCRM.Worker.start_link(arg)
        # {StoreCRM.Worker, arg},
        # Start to serve requests, typically the last entry
        StoreCRMWeb.Endpoint
      ]
      |> maybe_add_oban()

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StoreCRM.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_oban(children) do
    if Application.fetch_env!(:store_crm, :start_oban) do
      List.insert_at(children, 2, {Oban, Application.fetch_env!(:store_crm, Oban)})
    else
      children
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StoreCRMWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
