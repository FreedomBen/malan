defmodule MalanWeb.AdminLive.UsersTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  describe "GET /admin/users" do
    test "redirects to sign-in when unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/sign-in"}}} = live(conn, ~p"/admin/users")
    end

    test "redirects to sign-in when token belongs to a non-admin user", %{conn: conn} do
      {:ok, _user, session} = AccountsHelpers.regular_user_with_session()

      conn =
        conn
        |> Plug.Test.init_test_session(%{admin_api_token: session.api_token})

      assert {:error, {:redirect, %{to: "/admin/sign-in"}}} = live(conn, ~p"/admin/users")
    end

    test "lists users and shows the signed-in admin in the top bar", %{conn: conn} do
      {:ok, admin, admin_session} = AccountsHelpers.admin_user_with_session()
      {:ok, other, _} = AccountsHelpers.regular_user_with_session()

      conn =
        conn
        |> Plug.Test.init_test_session(%{admin_api_token: admin_session.api_token})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Users &amp; records" or html =~ "Users"
      assert html =~ admin.username
      assert html =~ other.email
    end

    test "filters results with ?q=", %{conn: conn} do
      {:ok, _admin, admin_session} = AccountsHelpers.admin_user_with_session()
      {:ok, needle, _} = AccountsHelpers.regular_user_with_session()
      {:ok, haystack, _} = AccountsHelpers.regular_user_with_session()

      conn =
        conn
        |> Plug.Test.init_test_session(%{admin_api_token: admin_session.api_token})

      {:ok, _view, html} = live(conn, ~p"/admin/users?q=#{needle.username}")

      assert html =~ needle.username
      refute html =~ haystack.email
    end
  end
end
