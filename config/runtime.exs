import Config

alias Malan.Utils

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Start the phoenix server if environment is set and running in a release

host = System.get_env("HOST") || "localhost"
port = System.get_env("PORT") || "4000"

external_host = System.get_env("EXTERNAL_HOST") || host
external_port = System.get_env("EXTERNAL_PORT") || port
external_scheme = System.get_env("EXTERNAL_SCHEME") || "http"

# If the external value isn't set, use value for value

config :malan, MalanWeb.Config.App,
  external_scheme: external_scheme,
  external_host: external_host,
  external_port: external_port

if System.get_env("HOST") && System.get_env("RELEASE_NAME") do
  config :malan, MalanWeb.Endpoint, server: true
end

### Begin LOG_LEVEL configuration

# Set the default log level based on the environment
allowed_log_levels = [:debug, :info, :warning, :error]

default_log_level =
  case config_env() do
    :prod -> "info"
    :test -> "warning"
    :dev -> "debug"
  end

# Fetch the LOG_LEVEL environment variable and configure logging
# Be permissive on the input, like "DEBUG", "debug", ":debug", etc.
log_level =
  System.get_env("LOG_LEVEL", default_log_level)
  |> String.trim_leading(":")
  |> String.downcase()
  |> String.to_atom()

if log_level in allowed_log_levels do
  Utils.Logger.info("Setting log level to #{log_level}")
  config :logger, level: log_level
else
  Utils.Logger.error(
    "Invalid log level: #{log_level}.  Valid levels are: " <>
      Malan.Utils.to_string(allowed_log_levels)
  )

  raise ArgumentError,
        "Invalid LOG_LEVEL environment variable value: #{log_level}.  Allowed values are: #{Malan.Utils.to_string(allowed_log_levels)}"
end

### End LOG_LEVEL configuration

# If it's non-prod, and MAILGUN_API_KEY is set, and MAILGUN_DISABLE is not set
if config_env() != :prod && !!System.get_env("MAILGUN_API_KEY") &&
     !System.get_env("MAILGUN_DISABLE") do
  Utils.Logger.warning(
    "config/runtime.exs:  MAILGUN_API_KEY is set!  We are using real mailgun for sending mail.  If this is not what you want, export MAILGUN_DISABLE=y"
  )

  config :malan, Malan.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: System.get_env("MAILGUN_API_KEY"),
    domain: System.get_env("MAILGUN_DOMAIN")
end

# PromEx metrics server port (default 9568, cluster-internal only)
metrics_port = System.get_env("METRICS_PORT", "9568") |> String.to_integer()

config :malan, Malan.PromEx,
  metrics_server: [
    port: metrics_port,
    path: "/metrics",
    protocol: :http,
    pool_size: 5,
    cowboy_opts: [],
    auth_strategy: :none
  ]

# Hammer/Redis rate limiter URL.
#
# `Malan.RateLimiter` uses Hammer's Redis backend so rate-limit counters
# are shared across pods (replaces the per-pod ETS bucket flagged in
# SECURITY_REVIEW_02_CODEX.md). In :prod the URL is required — refuse to
# boot rather than silently degrade to a single-node limiter. For :dev
# and :test we fall back to localhost so `scripts/start-redis.sh` works
# out of the box.
hammer_redis_url =
  case config_env() do
    :prod ->
      System.get_env("HAMMER_REDIS_URL") ||
        raise """
        environment variable HAMMER_REDIS_URL is missing.
        For example: redis://HOST:6379/0 (or rediss:// for TLS).
        """

    _ ->
      System.get_env("HAMMER_REDIS_URL") || "redis://localhost:6379/0"
  end

# When the URL is `rediss://`, override Erlang's default hostname-check
# function. Redix already supplies sensible TLS defaults — `verify:
# :verify_peer`, `depth: 3`, and `:cacerts` from `:public_key.cacerts_get/0`
# (OTP 25+) or castore — and DO Redis chains to a publicly-trusted CA, so
# we deliberately do *not* set `:cacertfile`/`:cacerts` here (doing so
# disables Redix's defaults, per its docs).
#
# What we *do* need to override is hostname matching. DO presents a leaf
# cert with the wildcard SAN `*.b.db.ondigitalocean.com`; Erlang's
# default match function rejects long single-label hostnames like
# `db-redis-nyc3-staging-do-user-7165198-0.b.db.ondigitalocean.com`
# against that wildcard. Installing the HTTPS-style match function
# applies RFC 6125 wildcard semantics and accepts the match.
#
# Hammer.Redis pops `:url` and `Keyword.merge`s the rest on top of the
# URL-derived start options, so `:socket_opts` reaches `Redix.start_link/1`.
hammer_redis_extra_opts =
  if String.starts_with?(hammer_redis_url, "rediss://") do
    [
      socket_opts: [
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]
  else
    []
  end

config :malan,
       Malan.RateLimiter,
       [url: hammer_redis_url] ++ hammer_redis_extra_opts

# Email verification auto-send: enabled by default. Accepts "true"/"1" or "false"/"0".
email_verification_auto_send? =
  case System.get_env("MALAN_EMAIL_VERIFICATION_AUTO_SEND") do
    nil -> true
    v when v in ["false", "0"] -> false
    v when v in ["true", "1"] -> true
    _ -> true
  end

config :malan, email_verification_auto_send: email_verification_auto_send?

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  # Postgrex deprecated the separate `ssl_opts` key — the keyword list is
  # now passed directly as `ssl:`. `false` disables TLS; the keyword form
  # enables it with the DO-managed Postgres CA cert as the trust anchor.
  # Resolve the cert via app_dir so the path works under a mix release,
  # where the app's priv/ lives at lib/malan-<vsn>/priv/, not at the cwd.
  database_ssl =
    if System.get_env("DATABASE_TLS_ENABLED") |> Utils.true_or_explicitly_false?() do
      [cacertfile: Application.app_dir(:malan, "priv/certs/do-db-ca-cert.crt")]

      # To provide mTLS client creds, append:
      # keyfile: Application.app_dir(:malan, "priv/client-key.pem"),
      # certfile: Application.app_dir(:malan, "priv/client-cert.pem")
    else
      false
    end

  config :malan, Malan.Repo,
    # socket_options: [:inet6],
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    ssl: database_ssl

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Cookie / LiveView signing & encryption salts. These are pulled into the
  # endpoint config below so `MalanWeb.Plugs.RuntimeSession` and the LiveView
  # socket's `connect_info: [session: {M, F, A}]` pick them up at runtime.
  # Generate values with `mix phx.gen.secret 16`.
  session_signing_salt =
    System.get_env("SESSION_SIGNING_SALT") ||
      raise """
      environment variable SESSION_SIGNING_SALT is missing.
      You can generate one by calling: mix phx.gen.secret 16
      """

  session_encryption_salt =
    System.get_env("SESSION_ENCRYPTION_SALT") ||
      raise """
      environment variable SESSION_ENCRYPTION_SALT is missing.
      You can generate one by calling: mix phx.gen.secret 16
      """

  live_view_signing_salt =
    System.get_env("LIVE_VIEW_SIGNING_SALT") ||
      raise """
      environment variable LIVE_VIEW_SIGNING_SALT is missing.
      You can generate one by calling: mix phx.gen.secret 16
      """

  # ## TLS / ingress contract
  #
  # TLS is terminated upstream of the app. Cloudflare speaks HTTPS to the
  # client; the DigitalOcean load balancer terminates TLS for the
  # cluster; the ingress forwards plain HTTP to the pod on port 4000
  # with `X-Forwarded-Proto: https`. We therefore bind only `http:` here
  # and rely on `force_ssl: [rewrite_on: [:x_forwarded_proto]]` (set in
  # config/prod.exs — it must be compile-time so the endpoint compiles
  # in `Plug.SSL`) to (a) detect the upstream TLS so legitimate HTTPS
  # requests are not redirected, and (b) add the
  # `Strict-Transport-Security` header on every response so future
  # visits never hit cleartext.
  #
  # K8s liveness/readiness probes hit the pod directly over HTTP without
  # `X-Forwarded-Proto`, so they receive a 301 to https. Kubelet treats
  # 200-399 status codes as healthy, so the redirect does not fail the
  # probe. If you ever need to terminate TLS at the app itself (e.g.
  # running outside the cluster) add an `https:` block here; see
  # https://hexdocs.pm/plug/Plug.SSL.html#configure/1.
  config :malan, MalanWeb.Endpoint,
    # url: is used for generating links in the application.
    url: [
      scheme: external_scheme,
      host: external_host,
      port: Utils.Number.to_int(external_port)
    ],
    # check_origin: :conn
    check_origin: [
      "https://accounts.ameelio.org",
      "https://accounts.ameelio.xyz",
      external_scheme <> "://" <> external_host
    ],
    # http: and https: are what's actually used for binding to an interface.
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: Utils.Number.to_int(port)
    ],
    live_view: [signing_salt: live_view_signing_salt],
    session_options: [
      store: :cookie,
      key: "_malan_key",
      signing_salt: session_signing_salt,
      encryption_salt: session_encryption_salt,
      # `secure: true` keeps browsers from sending the cookie if a
      # downgrade path appears (misconfigured ingress, exposed HTTP
      # listener, etc.). `same_site: "Lax"` mitigates CSRF on
      # state-changing top-level navigations while still allowing the
      # cookie on link clicks; `Strict` would break OAuth-style
      # callbacks where the redirect is initiated by a third-party.
      secure: true,
      same_site: "Lax"
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :malan, MalanWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
  # This only gets used if the environment is prod
  config :malan, Malan.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: System.get_env("MAILGUN_API_KEY"),
    domain: System.get_env("MAILGUN_DOMAIN")

  config :swoosh, :api_client, Swoosh.ApiClient.Hackney

  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: System.get_env("SENTRY_ENVIRONMENT", "unknown")
end
