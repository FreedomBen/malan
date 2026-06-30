defmodule Malan.RepoConfigTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Malan.RepoConfig

  # Regression guard: the Repo must use unnamed prepared statements so it stays
  # safe behind a transaction-mode connection pooler (PgBouncer). Named
  # statements are cached per server connection and break when the pooler hands
  # a later query to a different backend. See config/config.exs.
  test "Repo is configured with prepare: :unnamed for pooler safety" do
    assert Application.get_env(:malan, Malan.Repo)[:prepare] == :unnamed
  end

  describe "ssl_opts/1 — verify_full (in-cluster CloudNativePG pooler)" do
    setup do
      %{
        env: %{
          "DATABASE_SSL_MODE" => "verify_full",
          "PGSSLROOTCERT" => "/etc/cnpg/malan-pg/ca.crt",
          "PGHOST" => "malan-pg-pooler.malan-staging.svc.cluster.local"
        }
      }
    end

    test "enables peer verification against the mounted CA at the SNI host", %{env: env} do
      opts = RepoConfig.ssl_opts(env)

      assert opts[:verify] == :verify_peer
      assert opts[:cacertfile] == "/etc/cnpg/malan-pg/ca.crt"

      assert opts[:server_name_indication] ==
               ~c"malan-pg-pooler.malan-staging.svc.cluster.local"
    end

    test "verifies the hostname against the cert SANs — verify-full, not just verify-ca",
         %{env: env} do
      opts = RepoConfig.ssl_opts(env)

      # The hostname match_fun is what makes this verify-full: without it a cert
      # from any CA-trusted host would pass. This is the security-critical bit.
      assert Keyword.keyword?(opts[:customize_hostname_check])
      assert is_function(opts[:customize_hostname_check][:match_fun])
    end

    test "raises rather than silently downgrading when the CA path is absent", %{env: env} do
      assert_raise ArgumentError, ~r/PGSSLROOTCERT/, fn ->
        RepoConfig.ssl_opts(Map.delete(env, "PGSSLROOTCERT"))
      end
    end

    test "raises rather than silently downgrading when the host is absent", %{env: env} do
      assert_raise ArgumentError, ~r/PGHOST/, fn ->
        RepoConfig.ssl_opts(Map.delete(env, "PGHOST"))
      end
    end

    test "treats a blank CA path as absent", %{env: env} do
      assert_raise ArgumentError, ~r/PGSSLROOTCERT/, fn ->
        RepoConfig.ssl_opts(%{env | "PGSSLROOTCERT" => "  "})
      end
    end
  end

  describe "ssl_opts/1 — verify_ca (legacy DO-managed Postgres)" do
    test "trusts the baked-in DO CA with no hostname check" do
      opts = RepoConfig.ssl_opts(%{"DATABASE_SSL_MODE" => "verify_ca"})

      assert String.ends_with?(opts[:cacertfile], "priv/certs/do-db-ca-cert.crt")
      refute Keyword.has_key?(opts, :customize_hostname_check)
      refute Keyword.has_key?(opts, :verify)
    end

    test "is the default when DATABASE_TLS_ENABLED is truthy and no mode is set" do
      opts = RepoConfig.ssl_opts(%{"DATABASE_TLS_ENABLED" => "true"})
      assert String.ends_with?(opts[:cacertfile], "priv/certs/do-db-ca-cert.crt")
    end

    test "a blank DATABASE_SSL_MODE falls back to the legacy boolean" do
      opts =
        RepoConfig.ssl_opts(%{"DATABASE_SSL_MODE" => "", "DATABASE_TLS_ENABLED" => "true"})

      assert String.ends_with?(opts[:cacertfile], "priv/certs/do-db-ca-cert.crt")
    end
  end

  describe "ssl_opts/1 — disabled" do
    test "explicit disable" do
      assert RepoConfig.ssl_opts(%{"DATABASE_SSL_MODE" => "disable"}) == false
    end

    test "DATABASE_TLS_ENABLED explicitly false" do
      assert RepoConfig.ssl_opts(%{"DATABASE_TLS_ENABLED" => "false"}) == false
    end
  end

  describe "ssl_opts/1 — invalid input" do
    test "an unknown mode raises rather than guessing" do
      assert_raise ArgumentError, ~r/invalid DATABASE_SSL_MODE/, fn ->
        RepoConfig.ssl_opts(%{"DATABASE_SSL_MODE" => "verify_maybe"})
      end
    end
  end
end
