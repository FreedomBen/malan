defmodule Malan.PromEx do
  @moduledoc """
  Prometheus metrics exporter for Malan.

  Runs a dedicated HTTP server on a separate port (default 9568) that
  serves metrics at /metrics. This port should only be exposed
  cluster-internally (ClusterIP), not through any Ingress or
  LoadBalancer, so no authentication is required.
  """

  use PromEx, otp_app: :malan

  @impl true
  def plugins do
    [
      PromEx.Plugins.Application,
      PromEx.Plugins.Beam,
      {PromEx.Plugins.Phoenix, router: MalanWeb.Router, endpoint: MalanWeb.Endpoint},
      {PromEx.Plugins.Ecto, repos: [Malan.Repo]}
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"}
    ]
  end
end
