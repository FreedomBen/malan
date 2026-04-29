defmodule MalanWeb.EndpointTest do
  use ExUnit.Case, async: true

  describe "session_options/0" do
    test "sets same_site: \"Lax\" so cross-site embedded contexts cannot use the cookie" do
      opts = MalanWeb.Endpoint.session_options()
      assert Keyword.fetch!(opts, :same_site) == "Lax"
    end

    test "uses an encrypted cookie store with a non-empty key and salts" do
      opts = MalanWeb.Endpoint.session_options()
      assert Keyword.fetch!(opts, :store) == :cookie
      assert is_binary(Keyword.fetch!(opts, :key)) and Keyword.fetch!(opts, :key) != ""
      assert is_binary(Keyword.fetch!(opts, :signing_salt))
      assert is_binary(Keyword.fetch!(opts, :encryption_salt))
    end
  end

  describe "production-only cookie / transport hardening" do
    # `secure: true` and `same_site: "Lax"` live in the `if config_env() ==
    # :prod` block of `config/runtime.exs`. `force_ssl` lives in
    # `config/prod.exs` — Phoenix.Endpoint reads it via Application.compile_env,
    # so it must be compile-time config or the release aborts boot with a
    # compile/runtime mismatch. None of these are present in the test env's
    # loaded application config, so we assert against the source text instead
    # so a careless edit trips a test.
    @runtime_exs Path.join([__DIR__, "..", "..", "config", "runtime.exs"]) |> Path.expand()
    @prod_exs Path.join([__DIR__, "..", "..", "config", "prod.exs"]) |> Path.expand()

    test "prod block sets secure: true on the session cookie" do
      assert File.read!(@runtime_exs) =~ ~r/session_options:\s*\[[^\]]*secure:\s*true/s
    end

    test "prod block sets same_site: \"Lax\" on the session cookie" do
      assert File.read!(@runtime_exs) =~ ~r/session_options:\s*\[[^\]]*same_site:\s*"Lax"/s
    end

    test "prod compile-time config enables force_ssl with HSTS and X-Forwarded-Proto rewrite" do
      contents = File.read!(@prod_exs)
      assert contents =~ ~r/force_ssl:\s*\[[^\]]*hsts:\s*true/s
      assert contents =~ ~r/force_ssl:\s*\[[^\]]*rewrite_on:\s*\[:x_forwarded_proto\]/s
    end
  end
end
