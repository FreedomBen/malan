defmodule MalanWeb.UserVerifyEmailControllerTest do
  use MalanWeb.ConnCase, async: false

  import Ecto.Query, warn: false
  import Swoosh.TestAssertions

  alias Malan.Accounts
  alias Malan.Accounts.EmailVerificationEvent
  alias Malan.RateLimits.EmailVerification, as: EVRateLimit
  alias Malan.Repo
  alias Malan.Test.Helpers

  defp request_path(user_or_id), do: ~p"/api/users/#{user_or_id}/verify_email"
  defp verify_by_id_path(user_or_id, token), do: ~p"/api/users/#{user_or_id}/verify_email/#{token}"
  defp verify_by_token_path(token), do: ~p"/api/users/verify_email/#{token}"

  describe "POST /api/users/:id/verify_email (authenticated resend)" do
    test "returns 401/403 when unauthenticated" do
      {:ok, user} = Helpers.Accounts.regular_user()
      conn = post(build_conn(), request_path(user.id))
      # Standard unauth response per plan.  401 in this codebase.
      assert conn.status in [401, 403]
    end

    test "sends a verification email and returns status=sent" do
      {:ok, conn, user, _session} = authed_conn_for_regular_user()
      on_exit(fn -> EVRateLimit.clear(user.id) end)

      conn = post(conn, request_path(user.id))

      assert %{"ok" => true, "code" => 200, "status" => "sent"} =
               json_response(conn, 200)

      assert_email_sent(fn email ->
        assert email.subject == "Verify your Malan email address"
        assert Enum.any?(email.to, fn {_name, addr} -> addr == user.email end)
      end)

      db_user = Accounts.get_user!(user.id)
      refute is_nil(db_user.email_verification_token_hash)
      refute is_nil(db_user.email_verification_sent_at)
    end

    test "returns status=already_verified when user is verified" do
      {:ok, conn, user, _session} = authed_conn_for_regular_user()
      on_exit(fn -> EVRateLimit.clear(user.id) end)

      {:ok, _} = Accounts.set_email_verified(user, true)

      conn = post(conn, request_path(user.id))

      assert %{"ok" => true, "code" => 200, "status" => "already_verified"} =
               json_response(conn, 200)

      assert_no_email_sent()
    end

    test "returns 429 status=rate_limited when over rate limit" do
      {:ok, conn, user, _session} = authed_conn_for_regular_user()
      on_exit(fn -> EVRateLimit.clear(user.id) end)

      # Prime the rate limiter.
      assert {:ok, _} = Accounts.generate_email_verification(user)

      conn = post(conn, request_path(user.id))

      assert %{"ok" => false, "code" => 429, "status" => "rate_limited"} =
               json_response(conn, 429)
    end

    test "returns 404 for an unknown user" do
      {:ok, conn, _user, _session} = authed_conn_for_admin_user()
      conn = post(conn, request_path("nonexistent-user-id-12345"))
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/users/:id/verify_email/:token" do
    test "verifies email with valid token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      conn = put(build_conn(), verify_by_id_path(user.id, user.email_verification_token))

      assert %{"ok" => true, "code" => 200, "status" => "verified"} =
               json_response(conn, 200)

      db_user = Accounts.get_user!(user.id)
      refute is_nil(db_user.email_verified)
      assert is_nil(db_user.email_verification_token_hash)
    end

    test "returns 401 failed_invalid_token for a bad token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      conn = put(build_conn(), verify_by_id_path(user.id, "not-a-real-token"))

      assert %{"ok" => false, "status" => "failed_invalid_token"} =
               json_response(conn, 401)
    end

    test "returns 401 failed_expired_token for an expired token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      user
      |> Ecto.Changeset.change(%{email_verification_token_expires_at: past})
      |> Repo.update!()

      conn = put(build_conn(), verify_by_id_path(user.id, user.email_verification_token))

      assert %{"ok" => false, "status" => "failed_expired_token"} =
               json_response(conn, 401)
    end
  end

  describe "PUT /api/users/verify_email/:token (no id)" do
    test "verifies email by looking up via token hash" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      conn = put(build_conn(), verify_by_token_path(user.email_verification_token))

      assert %{"ok" => true, "status" => "verified"} = json_response(conn, 200)
    end

    test "returns 404 for an unknown token" do
      conn = put(build_conn(), verify_by_token_path("unknown-token-xyz"))
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/admin/users/:id (admin_update email_verified toggle)" do
    test "admin can set email_verified=true" do
      {:ok, admin_conn, _admin, _session} = authed_conn_for_admin_user()
      {:ok, user} = Helpers.Accounts.regular_user()
      assert is_nil(user.email_verified)

      conn =
        put(admin_conn, ~p"/api/admin/users/#{user.id}", user: %{email_verified: true})

      assert %{"data" => %{"email_verified" => email_verified}} = json_response(conn, 200)
      refute is_nil(email_verified)

      db_user = Accounts.get_user!(user.id)
      refute is_nil(db_user.email_verified)
    end

    test "admin can clear email_verified" do
      {:ok, admin_conn, _admin, _session} = authed_conn_for_admin_user()
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, _} = Accounts.set_email_verified(user, true)

      conn =
        put(admin_conn, ~p"/api/admin/users/#{user.id}", user: %{email_verified: false})

      assert %{"data" => %{"email_verified" => nil}} = json_response(conn, 200)

      db_user = Accounts.get_user!(user.id)
      assert is_nil(db_user.email_verified)
    end

    test "admin toggle clears any in-flight verification token" do
      {:ok, admin_conn, _admin, _session} = authed_conn_for_admin_user()
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)
      refute is_nil(user.email_verification_token_hash)

      _ = put(admin_conn, ~p"/api/admin/users/#{user.id}", user: %{email_verified: true})

      db_user = Accounts.get_user!(user.id)
      assert is_nil(db_user.email_verification_token_hash)
      assert is_nil(db_user.email_verification_token_expires_at)
    end
  end

  describe "POST /api/users (registration auto-send)" do
    test "enqueues a verification email on successful registration" do
      ui = System.unique_integer([:positive])

      attrs = %{
        email: "reg#{ui}@email.com",
        username: "reguser#{ui}",
        first_name: "Reg",
        last_name: "User",
        nick_name: "reggy"
      }

      conn = post(build_conn(), ~p"/api/users", user: attrs)
      assert %{"id" => user_id} = json_response(conn, 201)["data"]

      assert_email_sent(fn email ->
        assert email.subject == "Welcome to Malan — please verify your email"
        assert Enum.any?(email.to, fn {_name, addr} -> addr == attrs.email end)
      end)

      db_user = Accounts.get_user!(user_id)
      refute is_nil(db_user.email_verification_token_hash)
    end

    test "does NOT enqueue when the domain is on the skip list (@example.com)" do
      ui = System.unique_integer([:positive])

      attrs = %{
        email: "skippy#{ui}@example.com",
        username: "skipuser#{ui}",
        first_name: "Skip",
        last_name: "Py",
        nick_name: "skippy"
      }

      conn = post(build_conn(), ~p"/api/users", user: attrs)
      assert %{"id" => user_id} = json_response(conn, 201)["data"]

      assert_no_email_sent()

      events =
        Repo.all(
          from e in EmailVerificationEvent,
            where: e.user_id == ^user_id and e.event_type == "skipped_domain"
        )

      assert length(events) == 1
    end

    test "does NOT enqueue when auto-send flag is disabled; writes skipped_auto_send_disabled" do
      prev = Application.get_env(:malan, :email_verification_auto_send, true)
      Application.put_env(:malan, :email_verification_auto_send, false)

      on_exit(fn ->
        Application.put_env(:malan, :email_verification_auto_send, prev)
      end)

      ui = System.unique_integer([:positive])

      attrs = %{
        email: "flagoff#{ui}@email.com",
        username: "flagoff#{ui}",
        first_name: "Flag",
        last_name: "Off",
        nick_name: "off"
      }

      conn = post(build_conn(), ~p"/api/users", user: attrs)
      assert %{"id" => user_id} = json_response(conn, 201)["data"]

      assert_no_email_sent()

      events =
        Repo.all(
          from e in EmailVerificationEvent,
            where: e.user_id == ^user_id and e.event_type == "skipped_auto_send_disabled"
        )

      assert length(events) == 1

      db_user = Accounts.get_user!(user_id)
      assert is_nil(db_user.email_verified)
    end

    test "auto-send off still allows explicit authenticated resend" do
      prev = Application.get_env(:malan, :email_verification_auto_send, true)
      Application.put_env(:malan, :email_verification_auto_send, false)

      on_exit(fn ->
        Application.put_env(:malan, :email_verification_auto_send, prev)
      end)

      {:ok, conn, user, _session} = authed_conn_for_regular_user()
      on_exit(fn -> EVRateLimit.clear(user.id) end)

      conn = post(conn, request_path(user.id))

      assert %{"status" => "sent"} = json_response(conn, 200)

      assert_email_sent(fn email ->
        assert email.subject == "Verify your Malan email address"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Test support
  # ---------------------------------------------------------------------------

  defp authed_conn_for_regular_user do
    {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
    {:ok, conn, user, session}
  end

  defp authed_conn_for_admin_user do
    {:ok, conn, user, session} = Helpers.Accounts.admin_user_session_conn(build_conn())
    {:ok, conn, user, session}
  end

end
