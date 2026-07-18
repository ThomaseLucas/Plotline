defmodule Plotline.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PlotlineWeb.Telemetry,
      Plotline.Repo,
      Plotline.CatalogSync,
      {DNSCluster, query: Application.get_env(:plotline, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Plotline.PubSub},
      {Task.Supervisor, name: Plotline.TaskSupervisor},
      # Start to serve requests, typically the last entry
      PlotlineWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Plotline.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlotlineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
