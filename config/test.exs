import Config

# Only in tests, remove the complexity from the password hashing algorithm
# config :bcrypt_elixir, :log_rounds, 1
config :pbkdf2_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :malan, Malan.Repo,
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOSTNAME") || "127.0.0.1",
  database: "malan_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 98,
  ownership_timeout: :infinity

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :malan, MalanWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jhOV8WgGOt2XZ5iHeEKZ3/m2trLP5CJJSmZbaClcTXjquvkToAwRjaOET3zZhmho",
  server: false

# In test we don't send emails.
config :malan, Malan.Mailer, adapter: Swoosh.Adapters.Test

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :malan, :sentry, enabled: false
config :malan, :log_silence_record_log_warning, true

# config :malan, Malan.Accounts.User,
#   # Basically no rate limiting in test
#   password_reset_limit_count: 1_000_000,
#   password_reset_period_msecs: 1
