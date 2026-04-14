defmodule MalanWeb.AdminLive.UserDetailTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Malan.Accounts
  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  setup %{conn: conn} do
    {:ok, admin, admin_session} = AccountsHelpers.admin_user_with_session()

    conn =
      conn
      |> Plug.Test.init_test_session(%{admin_api_token: admin_session.api_token})

    %{conn: conn, admin: admin}
  end

  describe "GET /admin/users/:id" do
    test "redirects to sign-in when unauthenticated" do
      assert {:error, {:redirect, %{to: "/admin/sign-in"}}} =
               live(Phoenix.ConnTest.build_conn(), ~p"/admin/users/00000000-0000-0000-0000-000000000000")
    end

    test "renders username, email, and sessions section", %{conn: conn} do
      {:ok, target, target_session} = AccountsHelpers.regular_user_with_session()

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")

      assert html =~ target.username
      assert html =~ target.email
      assert html =~ "SESSIONS"
      assert html =~ target_session.ip_address
    end

    test "allows editing safe fields (first_name, display_name)", %{conn: conn} do
      {:ok, target, _session} = AccountsHelpers.regular_user_with_session()

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{target.id}")

      html =
        view
        |> form("form",
          user: %{
            "first_name" => "Renamed",
            "display_name" => "Dossier Display"
          }
        )
        |> render_submit()

      assert html =~ "Renamed"
      assert html =~ "Dossier Display"

      updated = Accounts.get_user(target.id)
      assert updated.first_name == "Renamed"
      assert updated.display_name == "Dossier Display"
    end

    test "redirects to users index for unknown id", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
               live(conn, ~p"/admin/users/00000000-0000-0000-0000-000000000000")
    end
  end
end
