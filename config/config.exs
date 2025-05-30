# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :malan,
  ecto_repos: [Malan.Repo],
  generators: [binary_id: true]

config :malan, Malan.Accounts.User,
  default_password_reset_token_expiration_secs:
    System.get_env("DEFAULT_PASSWORD_RESET_TOKEN_EXPIRATION_SECS") ||
      "86400" |> String.to_integer() # 24 hours

config :malan, Malan.Config.RateLimits,
  password_reset_lower_limit_msecs:
    System.get_env("PASSWORD_RESET_LOWER_LIMIT_MSECS") ||
      "180000" |> String.to_integer(), # 3 minutes (180 seconds)
  password_reset_lower_limit_count:
    System.get_env("PASSWORD_RESET_LOWER_LIMIT_COUNT") ||
      "1" |> String.to_integer(), # 1 per period
  password_reset_upper_limit_msecs:
    System.get_env("PASSWORD_RESET_UPPER_LIMIT_MSECS") ||
      "86400000" |> String.to_integer(), # 24 hours (86,400 seconds)
  password_reset_upper_limit_count:
    System.get_env("PASSWORD_RESET_UPPER_LIMIT_COUNT") ||
      "3" |> String.to_integer() # 1 per period

config :malan, Malan.Accounts.Session,
  # If client doesn't specify token expiration time, use this value.
  # 604,800 seconds is 7 days (One week)
  default_token_expiration_secs:
    System.get_env("DEFAULT_TOKEN_EXPIRATION_SECS") || "604800" |> String.to_integer(),
  # If client doesn't specify session extension limit, use this value.  This will be
  # used to determine an absolute maximum datetime beyond which a session cannot be extended
  # 2,419,200 seconds is 28 days
  default_max_extension_time_secs:
    System.get_env("DEFAULT_MAX_EXTENSION_TIME_SECS") || "2419200" |> String.to_integer(),
  # If client doesn't specify session extension limit per extension, use this value.
  # 604,800 is 7 days (one week)
  default_max_extension_secs:
    System.get_env("DEFAULT_MAX_EXTENSION_SECS") || "604800" |> String.to_integer(),
  # Most that a session can be extended, despite client settings.
  # 7,862,400 is approximately 90 days (13 weeks specifically)
  max_max_extension_secs:
    System.get_env("MAX_MAX_EXTENSION_SECS") || "7862400" |> String.to_integer()

# Configures the endpoint
config :malan, MalanWeb.Endpoint,
  url: [host: System.get_env("BIND_ADDR") || "127.0.0.1"],
  # render_errors: [view: MalanWeb.ErrorView, accepts: ~w(html json), layout: false],
  render_errors: [view: MalanWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Malan.PubSub,
  live_view: [signing_salt: "S5EXJrIi"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :malan, Malan.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, Swoosh.ApiClient.Hackney

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  colors: [enabled: true]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure MIME types
config :mime, :types, %{
  "application/json" => ["json"]
}

# Supplement Plug's list of statuses
# https://github.com/elixir-plug/plug/blob/master/lib/plug/conn/status.ex#L8-L72
config :plug, :statuses, %{
  461 => "Terms of Service Required",
  462 => "Privacy Policy Required"
}

# Known Plug Statuses:  https://hexdocs.pm/plug/Plug.Conn.Status.html#code/1-known-status-codes

config :hammer,
  backend: {
    Hammer.Backend.ETS,
    [
      expiry_ms: 60_000 * 60 * 4,       # 4 hours
      cleanup_interval_ms: 60_000 * 10  # 10 minutes
    ]
  }

# Sentry config.  DSN is runtime env var
# This handles most exceptions and Plug events
# https://hexdocs.pm/sentry/Sentry.html#content
config :sentry,
  filter: Malan.SentryEventFilter,
  before_send_event: {Malan.Sentry, :before_send},
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: config_env(),
    version: System.get_env("RELEASE_VERSION"), # set at buildtime by CI script
    compiled_at: DateTime.utc_now() |> DateTime.to_string()
  },
  included_environments: [:prod, :staging]

# Sentry Logger backend catches things that may get missed
# by plug if out of process, or just log messages for example.
# https://hexdocs.pm/sentry/Sentry.LoggerBackend.html
config :logger, Sentry.LoggerBackend,
  # Also send warn messages
  level: :warning,
  # Send messages from Plug/Cowboy
  excluded_domains: [],
  # Include metadata added with `Logger.metadata([foo_bar: "value"])`
  metadata: [:foo_bar],
  # Send messages like `Logger.error("error")` to Sentry
  capture_log_messages: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
