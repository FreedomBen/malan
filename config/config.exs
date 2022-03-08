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
      "1" |> String.to_integer() # 1 per period

config :malan, Malan.Accounts.Session,
  # One week
  default_token_expiration_secs:
    System.get_env("DEFAULT_TOKEN_EXPIRATION_SECS") || "604800" |> String.to_integer()

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
config :swoosh, :api_client, false

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
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
