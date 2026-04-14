defmodule MalanWeb.AdminLive.SignInTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  describe "GET /admin/sign-in" do
    test "renders the sign-in page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sign-in")
      assert html =~ "Sign"
      assert html =~ "Authorization"
    end
  end

  describe "POST /admin/sign_in" do
    test "redirects admin users into the console", %{conn: conn} do
      {:ok, admin} = AccountsHelpers.admin_user()

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> post(~p"/admin/sign_in", %{"username" => admin.username, "password" => admin.password})

      assert redirected_to(conn) == ~p"/admin/users"
      assert Plug.Conn.get_session(conn, :admin_api_token)
    end

    test "rejects non-admin users with a flash", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> post(~p"/admin/sign_in", %{"username" => user.username, "password" => user.password})

      assert redirected_to(conn) == ~p"/admin/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
      refute Plug.Conn.get_session(conn, :admin_api_token)
    end

    test "rejects bad passwords", %{conn: conn} do
      {:ok, admin} = AccountsHelpers.admin_user()

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> post(~p"/admin/sign_in", %{"username" => admin.username, "password" => "wrong"})

      assert redirected_to(conn) == ~p"/admin/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end
  end
end
