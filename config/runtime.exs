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

external_host = System.get_env("EXTERNAL_HOST") || host,
external_port = System.get_env("EXTERNAL_PORT") || port
external_scheme = System.get_env("EXTERNAL_SCHEME") || "http",

# If the external value isn't set, use value for value

config :malan, MalanWeb.Config.App,
  external_scheme: external_scheme,
  external_host: external_host,
  external_port: external_port


if System.get_env("HOST") && System.get_env("RELEASE_NAME") do
  config :malan, MalanWeb.Endpoint, server: true
end

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

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :malan, Malan.Repo,
    # socket_options: [:inet6],
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    ssl: System.get_env("DATABASE_TLS_ENABLED") |> Utils.true_or_explicitly_false?(),
    ssl_opts: [
      # To verify provider's self-signed cert
      cacertfile: "priv/certs/do-db-ca-cert.crt"

      # To provide mTLS client creds
      # keyfile: "priv/client-key.pem",
      # certfile: "priv/client-cert.pem"
    ]

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

  config :malan, MalanWeb.Endpoint,
    url: [host: external_host, port: Utils.Number.to_int(external_port)],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: Utils.Number.to_int(port)
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

  config :sentry, dsn: System.get_env("SENTRY_DSN")
end
