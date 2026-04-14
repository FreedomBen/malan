defmodule MalanWeb.UserAccountLiveTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  describe "GET /users/account" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/login"}}} = live(conn, ~p"/users/account")
    end

    test "shows username, email, and creation date for the logged-in user", %{conn: conn} do
      {:ok, user, session} = AccountsHelpers.regular_user_with_session()

      conn =
        conn
        |> Plug.Test.init_test_session(%{api_token: session.api_token})

      {:ok, _view, html} = live(conn, ~p"/users/account")

      assert html =~ "Your account"
      assert html =~ user.username
      assert html =~ user.email
      assert html =~ Calendar.strftime(user.inserted_at, "%Y-%m-%d")
    end

    test "redirects to login when session token is bogus", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{api_token: "not-a-real-token"})

      assert {:error, {:redirect, %{to: "/users/login"}}} = live(conn, ~p"/users/account")
    end
  end
end
