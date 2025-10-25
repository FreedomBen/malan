defmodule MalanWeb.UserResetPasswordLiveTest do
  use MalanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Malan.Accounts
  alias Malan.RateLimits.PasswordReset
  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers
  alias Swoosh.Adapters.Test, as: TestMailer

  @reset_path ~p"/users/reset_password"

  setup %{conn: conn} do
    TestMailer.reset()

    {:ok, conn: put_req_header(conn, "accept", "text/html")}
  end

  test "renders reset password form", %{conn: conn} do
    {:ok, _view, html} = live(conn, @reset_path)

    assert html =~ "Reset Password"
    assert html =~ "Send Reset Email"
  end

  test "shows error when email is not found", %{conn: conn} do
    {:ok, view, _html} = live(conn, @reset_path)

    html = render_submit(view, "send_reset_email", %{"email" => "missing@example.com"})

    assert html =~ "No user matching that email address was found"
    assert TestMailer.deliveries() == []
  end

  test "sends reset email and surfaces success message", %{conn: conn} do
    email = "live-reset-#{System.unique_integer([:positive])}@example.com"
    {:ok, user} = AccountsHelpers.regular_user(%{email: email})

    on_exit(fn -> PasswordReset.clear(user.id) end)

    {:ok, view, _html} = live(conn, @reset_path)

    html = render_submit(view, "send_reset_email", %{"email" => user.email})

    assert html =~ "Reset request received"

    [email] = TestMailer.deliveries()
    assert email.subject == "Your requested password reset token"
    assert Enum.any?(email.to, fn {_name, address} -> address == user.email end)

    db_user = Accounts.get_user_by_email(user.email)
    refute is_nil(db_user.password_reset_token_hash)
  end
end
