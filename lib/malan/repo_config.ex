defmodule Malan.RepoConfig do
  @moduledoc """
  Pure helpers for building `Malan.Repo`'s runtime connection config.

  The TLS logic lives here, not inline in `config/runtime.exs`, so it can be
  unit-tested: `runtime.exs` only evaluates its prod block under
  `config_env() == :prod` and is never loaded by the test suite.
  """

  alias Malan.Utils

  # CA cert for the legacy DigitalOcean-managed Postgres, baked into the release
  # image's priv/. Resolved via app_dir so the path is correct under a mix
  # release, where priv/ lives at lib/malan-<vsn>/priv/, not the cwd.
  @legacy_dbaas_ca "priv/certs/do-db-ca-cert.crt"

  @doc """
  Build the Postgrex `:ssl` option from the runtime environment (defaults to the
  real process environment).

  The mode comes from `DATABASE_SSL_MODE`, falling back to the legacy
  `DATABASE_TLS_ENABLED` boolean when it is unset or blank:

    * `"verify_full"` — full verification against the in-cluster CloudNativePG
      pooler: validate the server-cert chain to the CA file named by
      `PGSSLROOTCERT` *and* verify the hostname in `PGHOST` against the cert's
      SANs. Raises if either is missing — we never silently downgrade.
    * `"verify_ca"` — encrypt and trust the baked-in DO-managed Postgres CA with
      no hostname check (the DBaaS private cert carries no hostname SAN). Legacy
      behavior; the default when `DATABASE_TLS_ENABLED` is truthy.
    * `"disable"` — no TLS.

  Returns `false` (TLS off) or a keyword list suitable for `ssl:`.
  """
  @spec ssl_opts(map()) :: false | keyword()
  def ssl_opts(env \\ System.get_env()) do
    case ssl_mode(env) do
      :verify_full -> verify_full_opts(env)
      :verify_ca -> [cacertfile: legacy_ca_path()]
      :disable -> false
    end
  end

  # DATABASE_SSL_MODE wins when set; otherwise fall back to the legacy boolean.
  defp ssl_mode(env) do
    case present(env["DATABASE_SSL_MODE"]) do
      nil -> if tls_enabled?(env), do: :verify_ca, else: :disable
      mode -> parse_mode(mode)
    end
  end

  defp parse_mode(mode) do
    case mode |> String.trim() |> String.downcase() do
      m when m in ["verify_full", "verify-full"] ->
        :verify_full

      m when m in ["verify_ca", "verify-ca"] ->
        :verify_ca

      "disable" ->
        :disable

      other ->
        raise ArgumentError,
              "invalid DATABASE_SSL_MODE #{inspect(other)} " <>
                "(expected verify_full, verify_ca, or disable)"
    end
  end

  defp tls_enabled?(env), do: Utils.true_or_explicitly_false?(env["DATABASE_TLS_ENABLED"])

  # libpq's sslmode=verify-full. Postgrex needs it spelled out: it ignores
  # sslmode/sslrootcert from the connection URL, so the chain-to-CA plus the
  # hostname (SNI) matched against the cert SANs are configured here explicitly.
  defp verify_full_opts(env) do
    ca =
      present(env["PGSSLROOTCERT"]) ||
        raise ArgumentError,
              "DATABASE_SSL_MODE=verify_full requires PGSSLROOTCERT " <>
                "(the mounted CA cert path)"

    host =
      present(env["PGHOST"]) ||
        raise ArgumentError,
              "DATABASE_SSL_MODE=verify_full requires PGHOST " <>
                "(the server name verified against the cert SANs)"

    [
      verify: :verify_peer,
      cacertfile: ca,
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  defp legacy_ca_path, do: Application.app_dir(:malan, @legacy_dbaas_ca)

  # Treat nil and blank/whitespace strings alike so a present-but-empty env var
  # falls back instead of being taken as a (broken) value.
  defp present(nil), do: nil
  defp present(val) when is_binary(val), do: if(String.trim(val) == "", do: nil, else: val)
end
