defmodule MalanWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :malan

  # The session is stored in a cookie that is both signed and encrypted.
  # The salts are pulled from application config (see config/config.exs); they
  # default to historical values for backward compatibility but can be rotated
  # at build time via the SESSION_SIGNING_SALT / SESSION_ENCRYPTION_SALT env
  # vars. Plug.Session compiles these in, so rotation requires a rebuild.
  @session_options Application.compile_env!(:malan, [MalanWeb.Endpoint, :session_options])

  # socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, session: @session_options]]

  # If running behind CLoudflare, read the CF-Connection-IP header
  # and use that for `conn.remote_ip`
  # https://github.com/c-rack/plug_cloudflare
  # plug Plug.CloudFlare

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  # Use a custom plug to serve the Apple App Site Association file with the correct MIME type
  plug MalanWeb.Plugs.AppleAppSiteAssociationMime

  plug Plug.Static,
    at: "/",
    from: :malan,
    gzip: true,
    only: MalanWeb.static_paths(),
    content_types: %{
      ".well-known/assetlinks.json" => "application/json"
    }

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :malan
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  # The "log: false" in scope "/health_check", MalanWeb, log: false int he router
  # does not work.  Because of that, the health checks are logged everytime.
  # This causes the logs to be filled to the point of uselessness with health checks.
  # In order to silence the health check logs we use Unplug to conditionally
  # include them:  https://github.com/akoutmos/unplug
  # Health Checks are on /health_check/readiness and /health_check/liveness
  plug Unplug,
    if:
      {Unplug.Predicates.RequestPathNotIn,
       ["/metrics", "/health_check/liveness", "/health_check/readiness"]},
    do: {Plug.Telemetry, event_prefix: [:phoenix, :endpoint]}

  plug Unplug,
    if:
      {Unplug.Predicates.RequestPathNotIn,
       ["/metrics", "/health_check/liveness", "/health_check/readiness"]},
    do: Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Sentry.PlugContext
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MalanWeb.Router
end
