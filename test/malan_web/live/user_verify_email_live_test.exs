defmodule MalanWeb.UserVerifyEmailLiveTest do
  use MalanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Malan.Accounts
  alias Malan.Accounts.EmailVerificationEvent
  alias Malan.RateLimits.EmailVerification, as: EVRateLimit
  alias Malan.Repo
  alias Malan.Test.Helpers.Accounts, as: AccountsHelpers

  setup %{conn: conn} = context do
    set_swoosh_global(context)
    {:ok, conn: put_req_header(conn, "accept", "text/html")}
  end

  defp verify_path, do: ~p"/users/verify_email"
  defp verify_token_path(token), do: ~p"/users/verify_email/#{token}"

  describe "GET /users/verify_email (request/resend)" do
    test "redirects unauthenticated visitors to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/login"}}} = live(conn, verify_path())
    end

    test "renders the request page for an authenticated user", %{conn: conn} do
      {:ok, _user, session} = AccountsHelpers.regular_user_with_session()

      conn = Plug.Test.init_test_session(conn, %{api_token: session.api_token})

      {:ok, _view, html} = live(conn, verify_path())
      assert html =~ "Verify Email"
      assert html =~ "Send verification email"
    end

    test "sends verification email on submit and shows success", %{conn: conn} do
      {:ok, user, session} = AccountsHelpers.regular_user_with_session()
      on_exit(fn -> EVRateLimit.clear(user.id) end)

      conn = Plug.Test.init_test_session(conn, %{api_token: session.api_token})
      {:ok, view, _html} = live(conn, verify_path())

      html = render_submit(view, "send_verification_email", %{})

      assert html =~ "Verification email sent"

      assert_email_sent(fn email ->
        assert email.subject == "Verify your Malan email address"
        assert Enum.any?(email.to, fn {_name, addr} -> addr == user.email end)
      end)

      db_user = Accounts.get_user!(user.id)
      refute is_nil(db_user.email_verification_token_hash)
    end

    test "shows the already-verified message when the user is verified", %{conn: conn} do
      {:ok, user, session} = AccountsHelpers.regular_user_with_session()
      {:ok, _user} = Accounts.set_email_verified(user, true)

      conn = Plug.Test.init_test_session(conn, %{api_token: session.api_token})
      {:ok, view, _html} = live(conn, verify_path())

      html = render_submit(view, "send_verification_email", %{})

      assert html =~ "already verified"
      assert_no_email_sent()
    end

    test "captures the LiveView peer IP in email_verification_events", %{conn: conn} do
      import Ecto.Query, only: [from: 2]

      {:ok, user, session} = AccountsHelpers.regular_user_with_session()
      on_exit(fn -> EVRateLimit.clear(user.id) end)

      conn =
        conn
        |> Plug.Test.init_test_session(%{api_token: session.api_token})
        |> Plug.Conn.put_private(:live_view_connect_info, %{
          peer_data: %{address: {192, 0, 2, 99}, port: 12_345, ssl_cert: nil}
        })

      {:ok, view, _html} = live(conn, verify_path())
      _ = render_submit(view, "send_verification_email", %{})

      event =
        Repo.one(
          from e in EmailVerificationEvent,
            where: e.user_id == ^user.id,
            order_by: [desc: e.inserted_at, desc: e.id],
            limit: 1
        )

      refute is_nil(event), "expected an email_verification_events row"
      assert event.ip == "192.0.2.99"
    end

    test "shows too-many-requests message when rate limit trips", %{conn: conn} do
      {:ok, user, session} = AccountsHelpers.regular_user_with_session()
      on_exit(fn -> EVRateLimit.clear(user.id) end)

      # Prime the rate limiter
      assert {:ok, _} = Accounts.generate_email_verification(user)

      conn = Plug.Test.init_test_session(conn, %{api_token: session.api_token})
      {:ok, view, _html} = live(conn, verify_path())

      html = render_submit(view, "send_verification_email", %{})

      assert html =~ "Too many requests"
    end
  end

  describe "GET /users/verify_email/:token (token page)" do
    test "mount does NOT mutate state (link-prefetch safety)", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)
      raw = user.email_verification_token

      {:ok, _view, _html} = live(conn, verify_token_path(raw))

      db_user = Accounts.get_user!(user.id)
      assert is_nil(db_user.email_verified)
      refute is_nil(db_user.email_verification_token_hash)
    end

    test "explicit Confirm click verifies the email", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      {:ok, view, _html} = live(conn, verify_token_path(user.email_verification_token))

      html = render_submit(view, "confirm_verify", %{})

      assert html =~ "email has been verified"

      db_user = Accounts.get_user!(user.id)
      refute is_nil(db_user.email_verified)
      assert is_nil(db_user.email_verification_token_hash)
    end

    test "second Confirm click with same token shows invalid (single-use)", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      {:ok, view, _html} = live(conn, verify_token_path(user.email_verification_token))
      _ = render_submit(view, "confirm_verify", %{})

      # Reload the page with the same (now-consumed) token
      {:ok, view2, _html} = live(conn, verify_token_path(user.email_verification_token))
      html = render_submit(view2, "confirm_verify", %{})

      assert html =~ "invalid or has already been used"
    end

    test "shows invalid for an unknown token", %{conn: conn} do
      {:ok, view, _html} = live(conn, verify_token_path("totally-bogus-token"))
      html = render_submit(view, "confirm_verify", %{})

      assert html =~ "invalid or has already been used"
    end

    test "shows expired for an expired token", %{conn: conn} do
      {:ok, user} = AccountsHelpers.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      user
      |> Ecto.Changeset.change(%{email_verification_token_expires_at: past})
      |> Malan.Repo.update!()

      {:ok, view, _html} = live(conn, verify_token_path(user.email_verification_token))
      html = render_submit(view, "confirm_verify", %{})

      assert html =~ "expired"
    end
  end
end
