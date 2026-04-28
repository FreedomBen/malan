defmodule MalanWeb.UserResetPasswordTokenLiveTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Malan.Accounts
  alias Malan.RateLimits.PasswordReset
  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "text/html")}
  end

  test "resets password with a valid token", %{conn: conn} do
    {:ok, user} = AccountsHelpers.regular_user(%{})
    {:ok, user} = Accounts.generate_password_reset(user)

    on_exit(fn -> PasswordReset.clear(user.id) end)

    {:ok, view, _html} = live(conn, reset_token_path(user.password_reset_token))

    html = render_submit(view, "reset_password", %{"password" => "newpass123"})

    assert html =~ "The password was successfully changed."

    assert {:ok, _} =
             Accounts.authenticate_by_username_pass(user.username, "newpass123", "127.0.0.1")

    db_user = Accounts.get_user!(user.id)
    assert is_nil(db_user.password_reset_token_hash)
  end

  test "shows error for invalid or expired token", %{conn: conn} do
    {:ok, _view, html} = live(conn, reset_token_path("totally-invalid-token"))

    assert html =~ "The token is invalid, expired, or has already been used"
  end

  test "shows validation errors when password is too short", %{conn: conn} do
    {:ok, user} = AccountsHelpers.regular_user(%{})
    {:ok, user} = Accounts.generate_password_reset(user)

    on_exit(fn -> PasswordReset.clear(user.id) end)

    {:ok, view, _html} = live(conn, reset_token_path(user.password_reset_token))

    html = render_submit(view, "reset_password", %{"password" => "123"})

    assert html =~ "Encountered an error"
    min_length = Malan.Config.User.min_password_length()
    assert html =~ "at least #{min_length} character(s)"
  end

  test "captures the LiveView peer IP in the audit log on reset_password",
       %{conn: conn} do
    {:ok, user} = AccountsHelpers.regular_user(%{})
    {:ok, user} = Accounts.generate_password_reset(user)
    on_exit(fn -> PasswordReset.clear(user.id) end)

    conn =
      Plug.Conn.put_private(conn, :live_view_connect_info, %{
        peer_data: %{address: {198, 51, 100, 23}, port: 12_345, ssl_cert: nil}
      })

    {:ok, view, _html} = live(conn, reset_token_path(user.password_reset_token))
    _ = render_submit(view, "reset_password", %{"password" => "newpass123"})

    log =
      user.id
      |> Accounts.list_logs_by_user_id(0, 100)
      |> Enum.find(fn l -> l.what =~ "ResetPasswordToken" end)

    refute is_nil(log), "expected an audit log row for ResetPasswordToken"
    assert log.remote_ip == "198.51.100.23"
  end

  defp reset_token_path(token), do: ~p"/users/reset_password/#{token}"
end
