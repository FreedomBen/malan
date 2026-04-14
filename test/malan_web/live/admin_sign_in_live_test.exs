defmodule MalanWeb.AdminLive.SignInTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  describe "GET /admin/sign-in" do
    test "renders the sign-in page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sign-in")
      assert html =~ "Sign in to the admin console"
      assert html =~ "admin role"
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

    test "rejects locked admin accounts with a locked flash", %{conn: conn} do
      {:ok, admin} = AccountsHelpers.admin_user()
      {:ok, _} = AccountsHelpers.lock_user(admin)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> post(~p"/admin/sign_in", %{"username" => admin.username, "password" => admin.password})

      assert redirected_to(conn) == ~p"/admin/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "locked"
      refute Plug.Conn.get_session(conn, :admin_api_token)
    end

    test "rejects rate-limited sign-in attempts", %{conn: conn} do
      {:ok, admin} = AccountsHelpers.admin_user()

      original = Application.get_env(:malan, Malan.Config.RateLimits)

      on_exit(fn ->
        Application.put_env(:malan, Malan.Config.RateLimits, original)
        Malan.RateLimits.Login.clear(admin.username)
      end)

      Application.put_env(
        :malan,
        Malan.Config.RateLimits,
        Keyword.merge(original || [],
          login_limit_msecs: 60_000,
          login_limit_count: 1
        )
      )

      Malan.RateLimits.Login.clear(admin.username)

      first =
        conn
        |> Plug.Test.init_test_session(%{})
        |> post(~p"/admin/sign_in", %{"username" => admin.username, "password" => "wrong"})

      assert redirected_to(first) == ~p"/admin/sign-in"

      second =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> post(~p"/admin/sign_in", %{"username" => admin.username, "password" => admin.password})

      assert redirected_to(second) == ~p"/admin/sign-in"
      assert Phoenix.Flash.get(second.assigns.flash, :error) =~ "Too many"
      refute Plug.Conn.get_session(second, :admin_api_token)
    end
  end

  describe "DELETE /admin/sign_out" do
    test "revokes the admin session token server-side", %{conn: conn} do
      {:ok, _admin, session} = AccountsHelpers.admin_user_with_session()

      conn =
        conn
        |> Plug.Test.init_test_session(%{admin_api_token: session.api_token})
        |> delete(~p"/admin/sign_out")

      assert redirected_to(conn) == ~p"/admin/sign-in"

      reloaded = Malan.Repo.get!(Malan.Accounts.Session, session.id)
      assert reloaded.revoked_at != nil
    end
  end
end
