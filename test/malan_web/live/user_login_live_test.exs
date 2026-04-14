defmodule MalanWeb.UserLoginLiveTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  describe "GET /users/login" do
    test "renders the login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/login")
      assert html =~ "Log in"
      assert html =~ "Username"
      assert html =~ "Password"
      assert html =~ "Forgot your password?"
    end
  end

  describe "POST /users/log_in" do
    test "stores api_token in session and redirects on valid credentials", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()

      conn =
        post(conn, ~p"/users/log_in", %{
          "username" => user.username,
          "password" => user.password
        })

      assert redirected_to(conn) == ~p"/users/account"
      assert is_binary(get_session(conn, :api_token))
    end

    test "redirects back to login with flash on bad credentials", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()

      conn =
        post(conn, ~p"/users/log_in", %{
          "username" => user.username,
          "password" => "wrong-password"
        })

      assert redirected_to(conn) == ~p"/users/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid"
      refute get_session(conn, :api_token)
    end
  end

  describe "DELETE /users/log_out" do
    test "clears the session and redirects to login", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()

      conn =
        post(conn, ~p"/users/log_in", %{
          "username" => user.username,
          "password" => user.password
        })

      assert get_session(conn, :api_token)

      conn =
        conn
        |> recycle()
        |> Plug.Test.init_test_session(%{api_token: get_session(conn, :api_token)})
        |> delete(~p"/users/log_out")

      assert redirected_to(conn) == ~p"/users/login"
      assert conn.private[:plug_session_info] == :drop
    end
  end
end
