defmodule MalanWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :malan

  # The session is stored in a cookie that is both signed and encrypted.
  # Salts live in runtime application config (`config/runtime.exs`, populated
  # from SESSION_SIGNING_SALT / SESSION_ENCRYPTION_SALT / LIVE_VIEW_SIGNING_SALT
  # env vars in prod) — they are *not* compiled into the release. The HTTP
  # pipeline reads them via `MalanWeb.Plugs.RuntimeSession`, which wraps
  # `Plug.Session`, and the LiveView socket reads them at WS connect time via
  # the `{module, function, args}` form of `:session` in `connect_info`.

  # `:x_headers` exposes request headers (including `cf-connecting-ip`)
  # to LiveView mounts so `MalanWeb.RealIp.from_connect_info/1` can
  # prefer the Cloudflare-reported IP, mirroring the HTTP-side plug.
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [
        :peer_data,
        :x_headers,
        session: {__MODULE__, :session_options, []}
      ]
    ]

  @doc """
  Returns the cookie session options from runtime application config.

  Invoked by `MalanWeb.Plugs.RuntimeSession` (HTTP pipeline) and by Phoenix
  at WS connect time (via the MFA tuple in the LiveView socket's
  `connect_info`). Reads `:malan, MalanWeb.Endpoint, :session_options`,
  which `config/runtime.exs` overrides from env vars in prod.
  """
  def session_options do
    :malan
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:session_options)
  end

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

  # In production we terminate at Cloudflare; rewrite `conn.remote_ip`
  # from `CF-Connecting-IP` so all downstream plugs (Sentry context,
  # controllers, rate limits, audit logs) see the real client IP.
  plug MalanWeb.Plugs.CloudflareRealIp

  plug Sentry.PlugContext
  plug Plug.MethodOverride
  plug Plug.Head
  plug MalanWeb.Plugs.RuntimeSession
  plug MalanWeb.Router
end
