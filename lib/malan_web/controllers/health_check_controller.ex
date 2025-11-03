defmodule MalanWeb.HealthCheckController do
  use MalanWeb, {:controller, formats: [:json], layouts: []}

  action_fallback MalanWeb.FallbackController

  def liveness(conn, _params) do
    send_resp(conn, 200, "")
  end

  def readiness(conn, _params) do
    send_resp(conn, 200, "")
  end
end
