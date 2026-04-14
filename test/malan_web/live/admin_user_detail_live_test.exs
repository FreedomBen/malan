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
      assert html =~ "Sessions"
      assert html =~ target_session.ip_address
    end

    test "allows editing safe fields (first_name, display_name)", %{conn: conn} do
      {:ok, target, _session} = AccountsHelpers.regular_user_with_session()

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{target.id}")

      html =
        view
        |> form("form[phx-submit=save]",
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

    test "edit form does not expose unsafe fields (mass-assignment guard)",
         %{conn: conn} do
      {:ok, target, _session} = AccountsHelpers.regular_user_with_session()

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")

      assert html =~ ~s(name="user[first_name]")

      for unsafe <- ~w(email username password password_hash roles locked_at deleted_at) do
        refute html =~ ~s(name="user[#{unsafe}]"),
               "edit form must not surface unsafe field user[#{unsafe}]"
      end
    end

    test "server-side filter drops unsafe fields from save params",
         %{conn: conn} do
      {:ok, target, _session} = AccountsHelpers.regular_user_with_session()
      original_email = target.email
      original_username = target.username
      original_hash = target.password_hash

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{target.id}")

      send(
        view.pid,
        %Phoenix.Socket.Message{
          event: "event",
          topic: "lv:#{view.id}",
          payload: %{
            "type" => "form",
            "event" => "save",
            "value" =>
              URI.encode_query(%{
                "user[first_name]" => "Legit",
                "user[email]" => "hacked@evil.example",
                "user[username]" => "hijacked",
                "user[password]" => "NewPlaintext!123",
                "user[password_hash]" => "$2b$12$forged.hash.value.1234567890abcdefgh"
              })
          }
        }
      )

      _ = render(view)

      updated = Accounts.get_user(target.id)
      assert updated.first_name == "Legit"
      assert updated.email == original_email
      assert updated.username == original_username
      assert updated.password_hash == original_hash
    end
  end
end
