defmodule MalanWeb.SessionControllerIpThrottleTest do
  # async: false — these tests lower the global per-IP login limits via
  # Application.put_env; concurrent tests logging in would trip the
  # lowered limits (or see their config clobbered).
  use MalanWeb.ConnCase, async: false

  alias Malan.RateLimits.Login
  alias Malan.Test.Helpers

  # Test config sets the per-IP login counts to 1_000_000 so the rest of
  # the suite (which logs in from 127.0.0.1 constantly) never trips them.
  # Lower them here to exercise the deny path. The per-username limit is
  # lowered too so the first test can detect whether an IP-denied attempt
  # leaks a hit into the per-username bucket.
  setup do
    prev = Application.get_env(:malan, Malan.Config.RateLimits)

    Application.put_env(
      :malan,
      Malan.Config.RateLimits,
      prev
      |> Keyword.put(:login_ip_lower_limit_count, 3)
      |> Keyword.put(:login_limit_msecs, 60_000)
      |> Keyword.put(:login_limit_count, 4)
    )

    on_exit(fn -> Application.put_env(:malan, Malan.Config.RateLimits, prev) end)

    :ok
  end

  defp login(cf_ip, username, password) do
    conn = build_conn()

    conn
    |> put_req_header("cf-connecting-ip", cf_ip)
    |> post(Routes.session_path(conn, :create),
      session: %{username: username, password: password}
    )
  end

  test "denies with 429 at the per-IP limit without consuming the per-username bucket" do
    {:ok, user} = Helpers.Accounts.regular_user()
    cf_ip = "198.51.100.201"

    on_exit(fn ->
      Login.PerIp.clear(cf_ip)
      Login.clear(user.username)
    end)

    {:ok, _} = Login.PerIp.clear(cf_ip)
    {:ok, _} = Login.clear(user.username)

    # Three wrong-password attempts exhaust the per-IP lower bucket (3).
    for _ <- 1..3 do
      assert json_response(login(cf_ip, user.username, "wrongpassword"), 403)
    end

    # The 4th attempt is denied by IP before any hashing or DB work —
    # even with the correct password.
    assert json_response(login(cf_ip, user.username, user.password), 429)

    # The denied attempt must not have consumed the per-username bucket
    # (limit 4): after clearing only the IP bucket, this login is the 4th
    # username hit and still fits. Had the IP-denied attempt leaked a hit
    # into the username bucket, this would be hit 5 and 429.
    {:ok, _} = Login.PerIp.clear(cf_ip)

    assert %{"data" => %{"api_token" => _}} =
             json_response(login(cf_ip, user.username, user.password), 201)
  end

  test "an exhausted IP does not affect logins from a different IP" do
    {:ok, user} = Helpers.Accounts.regular_user()
    attacker_ip = "198.51.100.202"
    victim_ip = "198.51.100.203"

    on_exit(fn ->
      Login.PerIp.clear(attacker_ip)
      Login.PerIp.clear(victim_ip)
      Login.clear(user.username)
    end)

    {:ok, _} = Login.PerIp.clear(attacker_ip)
    {:ok, _} = Login.PerIp.clear(victim_ip)

    # Spraying distinct usernames gets a fresh per-username bucket on
    # every attempt; only the per-IP bucket can stop the spray.
    for i <- 1..3 do
      assert json_response(login(attacker_ip, "nosuchuser#{i}", "somepassword"), 403)
    end

    assert json_response(login(attacker_ip, "nosuchuser99", "somepassword"), 429)

    # A different client IP is unaffected.
    assert %{"data" => %{"api_token" => _}} =
             json_response(login(victim_ip, user.username, user.password), 201)
  end
end
