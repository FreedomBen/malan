defmodule MalanWeb.UserResetPasswordLiveTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Malan.Accounts
  alias Malan.RateLimits.PasswordReset
  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  defmodule FailingMailAdapter do
    @behaviour Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: {:error, {401, "unauthorized"}}

    @impl true
    def validate_config(_config), do: :ok
  end

  setup %{conn: conn} = context do
    set_swoosh_global(context)

    {:ok, conn: put_req_header(conn, "accept", "text/html")}
  end

  test "renders reset password form", %{conn: conn} do
    {:ok, _view, html} = live(conn, reset_path())

    assert html =~ "Reset Password"
    assert html =~ "Send Reset Email"
  end

  test "shows error when email is not found", %{conn: conn} do
    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => "missing@example.com"})

    assert html =~ "No user matching that email address was found"
    assert_no_email_sent()
  end

  test "sends reset email and surfaces success message", %{conn: conn} do
    email = "live-reset-#{System.unique_integer([:positive])}@example.com"
    {:ok, user} = AccountsHelpers.regular_user(%{email: email})

    on_exit(fn -> PasswordReset.clear(user.id) end)

    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => user.email})

    assert html =~ "Reset request received"

    assert_email_sent(fn delivered ->
      assert delivered.subject == "Your requested password reset token"
      assert Enum.any?(delivered.to, fn {_name, address} -> address == user.email end)
      true
    end)

    db_user = Accounts.get_user_by_email(user.email)
    refute is_nil(db_user.password_reset_token_hash)
  end

  defp reset_path, do: ~p"/users/reset_password"

  test "shows rate limit error when reset requested too frequently", %{conn: conn} do
    {:ok, user} = AccountsHelpers.regular_user(%{})

    on_exit(fn -> PasswordReset.clear(user.id) end)

    assert {:ok, _} = Accounts.generate_password_reset(user)

    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => user.email})

    assert html =~ "Too many requests"
    assert_no_email_sent()
  end

  test "surfaces internal error when mail provider rejects credentials", %{conn: conn} do
    prev_mailer_config = Application.get_env(:malan, Malan.Mailer)
    Application.put_env(:malan, Malan.Mailer, Keyword.put(prev_mailer_config, :adapter, FailingMailAdapter))

    on_exit(fn -> Application.put_env(:malan, Malan.Mailer, prev_mailer_config) end)

    {:ok, user} = AccountsHelpers.regular_user(%{})

    {:ok, view, _html} = live(conn, reset_path())

    html = render_submit(view, "send_reset_email", %{"email" => user.email})

    assert html =~ "experienced an internal error"
  end
end
