defmodule MalanWeb.UserControllerRegistrationThrottleTest do
  # async: false — these tests lower the global per-IP registration
  # limits via Application.put_env (and one stops the shared rate
  # limiter); concurrent tests registering users would trip the lowered
  # limits or see their config clobbered.
  use MalanWeb.ConnCase, async: false

  alias Malan.Accounts
  alias Malan.RateLimits.Registration

  # Test config sets the per-IP registration counts to 1_000_000 so the
  # rest of the suite (which registers users from 127.0.0.1 constantly)
  # never trips them. Lower the lower bucket here to exercise the deny
  # path.
  setup do
    prev = Application.get_env(:malan, Malan.Config.RateLimits)

    Application.put_env(
      :malan,
      Malan.Config.RateLimits,
      Keyword.put(prev, :registration_ip_lower_limit_count, 2)
    )

    on_exit(fn -> Application.put_env(:malan, Malan.Config.RateLimits, prev) end)

    :ok
  end

  defp register(cf_ip, i) do
    conn = build_conn()

    conn
    |> put_req_header("cf-connecting-ip", cf_ip)
    |> post(Routes.user_path(conn, :create),
      user: %{
        username: "throttleuser#{i}",
        email: "throttleuser#{i}@example.com",
        first_name: "Throttle",
        last_name: "User#{i}",
        password: "averygoodpassword#{i}"
      }
    )
  end

  test "denies with 429 once the per-IP limit is hit and creates no user" do
    cf_ip = "198.51.100.210"
    other_ip = "198.51.100.211"

    on_exit(fn ->
      Registration.PerIp.clear(cf_ip)
      Registration.PerIp.clear(other_ip)
    end)

    {:ok, _} = Registration.PerIp.clear(cf_ip)
    {:ok, _} = Registration.PerIp.clear(other_ip)

    # Under the lowered limit (2/min) registrations succeed.
    assert json_response(register(cf_ip, 1), 201)
    assert json_response(register(cf_ip, 2), 201)

    # Over the limit: 429 and no user row is created.
    assert json_response(register(cf_ip, 3), 429)
    assert is_nil(Accounts.get_user_by_id_or_username("throttleuser3"))

    # A different client IP is unaffected.
    assert json_response(register(other_ip, 4), 201)
  end

  test "private (cluster-internal) client IPs are not per-IP limited" do
    # Six registrations from one private IP — three times the lowered
    # limit (2) — all succeed.
    for i <- 10..15 do
      assert json_response(register("10.244.5.22", i), 201)
    end
  end

  test "registration fails open when the rate limiter is unavailable" do
    # Take the Hammer.Redis pool offline so check_rate returns
    # {:error, :rate_limiter_unavailable}; registration must proceed.
    :ok = Supervisor.terminate_child(Malan.Supervisor, Malan.RateLimiter)

    on_exit(fn ->
      {:ok, _} = Supervisor.restart_child(Malan.Supervisor, Malan.RateLimiter)
    end)

    assert json_response(register("198.51.100.212", 5), 201)
    refute is_nil(Accounts.get_user_by_id_or_username("throttleuser5"))
  end
end
