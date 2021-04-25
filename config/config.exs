# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :malan,
  ecto_repos: [Malan.Repo],
  generators: [binary_id: true]

# Configures the endpoint
config :malan, MalanWeb.Endpoint,
  url: [host: System.get_env("BIND_ADDR") || "127.0.0.1"],
  secret_key_base: "FC5AU8NzrLTUTK3z70VVpDMKMYA9t3i4ptS94tW+N9+zZk0SdF26Dia44OEVkHWX",
  render_errors: [view: MalanWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Malan.PubSub,
  live_view: [signing_salt: "6nlG1XZd"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :plug, :statuses, %{
  461 => "Terms of Service Required",
  462 => "Privacy Policy Required"
}

config :my_app, Malan.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: System.get_env("SMTP_ENDPOINT"),
  port: System.get_env("SMTP_PORT") || 1025,
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :if_available, # can be `:always` or `:never`
  ssl: false, # can be `true`
  retries: 1

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
