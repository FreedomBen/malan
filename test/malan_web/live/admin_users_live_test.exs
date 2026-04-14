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

    test "clear_search event resets the filter", %{conn: conn} do
      {:ok, _admin, admin_session} = AccountsHelpers.admin_user_with_session()
      {:ok, needle, _} = AccountsHelpers.regular_user_with_session()
      {:ok, other, _} = AccountsHelpers.regular_user_with_session()

      conn =
        conn
        |> Plug.Test.init_test_session(%{admin_api_token: admin_session.api_token})

      {:ok, view, html} = live(conn, ~p"/admin/users?q=#{needle.username}")
      assert html =~ needle.username
      refute html =~ other.email

      html_after = render_click(view, "clear_search", %{})
      assert html_after =~ other.email
    end

    test "rejects sessions whose stored IP does not match the request", %{conn: conn} do
      {:ok, _admin, admin_session} = AccountsHelpers.admin_user_with_session()

      admin_session
      |> Ecto.Changeset.change(ip_address: "10.99.99.99", valid_only_for_ip: true)
      |> Malan.Repo.update!()

      conn =
        conn
        |> Plug.Test.init_test_session(%{admin_api_token: admin_session.api_token})

      assert {:error, {:redirect, %{to: "/admin/sign-in"}}} = live(conn, ~p"/admin/users")
    end

    test "paginates with ?page= when results exceed page_size", %{conn: conn} do
      {:ok, _admin, admin_session} = AccountsHelpers.admin_user_with_session()

      for _ <- 1..26 do
        {:ok, _user, _session} = AccountsHelpers.regular_user_with_session()
      end

      conn =
        conn
        |> Plug.Test.init_test_session(%{admin_api_token: admin_session.api_token})

      {:ok, _view, page0} = live(conn, ~p"/admin/users?page=0")
      {:ok, _view, page1} = live(conn, ~p"/admin/users?page=1")

      emails = fn html ->
        Regex.scan(~r/[a-z0-9._+-]+@[a-z0-9.-]+/i, html)
        |> List.flatten()
        |> MapSet.new()
      end

      p0 = emails.(page0)
      p1 = emails.(page1)

      assert MapSet.size(p0) > 0
      assert MapSet.size(p1) > 0
      refute MapSet.equal?(p0, p1)
    end
  end
end
