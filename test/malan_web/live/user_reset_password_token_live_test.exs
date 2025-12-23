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
    assert html =~ "at least"
  end

  defp reset_token_path(token), do: ~p"/users/reset_password/#{token}"
end
