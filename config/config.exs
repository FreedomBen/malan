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

config :malan, Malan.Accounts.User,
  default_password_reset_token_expiration_secs: System.get_env("DEFAULT_PASSWORD_RESET_TOKEN_EXPIRATION_SECS") || "86400" |> String.to_integer() # 24 hours

config :malan, Malan.Accounts.Session,
  default_token_expiration_secs: System.get_env("DEFAULT_TOKEN_EXPIRATION_SECS") || "604800" |> String.to_integer() # One week

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
