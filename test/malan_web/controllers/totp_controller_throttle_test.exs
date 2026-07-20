defmodule MalanWeb.TotpControllerThrottleTest do
  # async: false — these tests lower the global TotpVerify limits via
  # Application.put_env; concurrent MFA tests would trip the lowered
  # limits (or see their config clobbered).
  use MalanWeb.ConnCase, async: false

  alias Malan.Accounts
  alias Malan.RateLimits.TotpVerify
  alias Malan.Test.Helpers

  # Test config sets the TotpVerify counts to 1_000_000 so the rest of the
  # suite never trips them. Lower the lower bucket here to exercise the
  # deny path on each code-accepting surface; the upper bucket stays high
  # (its logic is identical and is covered by the shared parent module).
  setup do
    prev = Application.get_env(:malan, Malan.Config.RateLimits)

    Application.put_env(
      :malan,
      Malan.Config.RateLimits,
      prev
      |> Keyword.put(:totp_verify_lower_limit_msecs, 300_000)
      |> Keyword.put(:totp_verify_lower_limit_count, 2)
    )

    on_exit(fn -> Application.put_env(:malan, Malan.Config.RateLimits, prev) end)

    :ok
  end

  defp assert_429(conn) do
    assert %{"ok" => false, "code" => 429, "detail" => "Too Many Requests"} =
             json_response(conn, 429)
  end

  test "the limiter fires on login code guessing" do
    {:ok, user, _secret, _codes} = Helpers.Accounts.regular_user_with_totp()
    on_exit(fn -> TotpVerify.clear(user.id) end)

    login = fn code ->
      conn = build_conn()

      post(conn, Routes.session_path(conn, :create),
        session: %{username: user.username, password: user.password, totp_code: code}
      )
    end

    assert json_response(login.("000000"), 403)["invalid_mfa_code"]
    assert json_response(login.("000000"), 403)["invalid_mfa_code"]
    assert_429(login.("000000"))
  end

  test "the limiter fires on confirm, not just login" do
    {:ok, user} = Helpers.Accounts.regular_user()
    {:ok, verified} = Accounts.set_email_verified(user, true)
    user = %{verified | password: user.password}
    {:ok, session} = Helpers.Accounts.create_session(user)
    conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
    on_exit(fn -> TotpVerify.clear(user.id) end)

    # enrollment start consumes one slot (password verification surface)…
    assert post(conn, Routes.user_totp_path(conn, :create, user.id), password: user.password)
           |> json_response(201)

    # …the buckets were cleared by its success, so two bad confirms fit
    assert put(conn, Routes.user_totp_path(conn, :confirm, user.id), code: "000000")
           |> json_response(403)

    assert put(conn, Routes.user_totp_path(conn, :confirm, user.id), code: "000000")
           |> json_response(403)

    assert_429(put(conn, Routes.user_totp_path(conn, :confirm, user.id), code: "000000"))
  end

  test "the limiter fires on disable and regenerate" do
    {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

    {:ok, session} =
      Helpers.Accounts.create_session(user, %{
        "totp_code" => NimbleTOTP.verification_code(secret)
      })

    conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
    on_exit(fn -> TotpVerify.clear(user.id) end)
    # the login above consumed a slot then cleared the buckets on success

    assert post(conn, Routes.user_totp_path(conn, :disable, user.id),
             password: "WrongPassword123",
             code: "000000"
           )
           |> json_response(403)

    assert post(conn, Routes.user_totp_path(conn, :regenerate_backup_codes, user.id),
             password: "WrongPassword123",
             code: "000000"
           )
           |> json_response(403)

    assert_429(
      post(conn, Routes.user_totp_path(conn, :disable, user.id),
        password: "WrongPassword123",
        code: "000000"
      )
    )
  end
end
