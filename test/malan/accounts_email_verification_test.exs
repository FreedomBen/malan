defmodule Malan.AccountsEmailVerificationTest do
  use Malan.DataCase, async: false

  import Ecto.Query, warn: false

  alias Malan.{Accounts, Repo}
  alias Malan.Accounts.{User, EmailVerificationEvent}
  alias Malan.Test.Helpers

  describe "generate_email_verification/2" do
    test "issues token and writes :requested audit row" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, %User{} = user_with_token} =
               Accounts.generate_email_verification(user, rate_limit?: false)

      assert is_binary(user_with_token.email_verification_token)
      assert is_binary(user_with_token.email_verification_token_hash)
      refute is_nil(user_with_token.email_verification_token_expires_at)
      refute is_nil(user_with_token.email_verification_sent_at)

      events =
        Repo.all(from e in EmailVerificationEvent, where: e.user_id == ^user.id)

      assert Enum.any?(events, &(&1.event_type == "requested"))
    end

    test "returns :already_verified when user is already verified" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.set_email_verified(user, true)

      assert {:ok, :already_verified} = Accounts.generate_email_verification(user)

      events =
        Repo.all(
          from e in EmailVerificationEvent,
            where: e.user_id == ^user.id and e.event_type == "skipped_already_verified"
        )

      assert length(events) >= 1
    end

    test "returns :skipped_domain for @example.com email" do
      ui = System.unique_integer([:positive])

      {:ok, user} =
        Helpers.Accounts.regular_user(%{
          email: "skippy#{ui}@example.com",
          username: "skippy#{ui}"
        })

      assert {:ok, :skipped_domain} = Accounts.generate_email_verification(user)

      events =
        Repo.all(
          from e in EmailVerificationEvent,
            where: e.user_id == ^user.id and e.event_type == "skipped_domain"
        )

      assert length(events) == 1
    end

    test "returns :skipped_auto_send_disabled when auto-send off and context is :welcome" do
      prev = Application.get_env(:malan, :email_verification_auto_send, true)
      Application.put_env(:malan, :email_verification_auto_send, false)

      on_exit(fn ->
        Application.put_env(:malan, :email_verification_auto_send, prev)
      end)

      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, :skipped_auto_send_disabled} =
               Accounts.generate_email_verification(user, rate_limit?: false, context: :welcome)
    end

    test "auto-send off does NOT block an explicit :resend context" do
      prev = Application.get_env(:malan, :email_verification_auto_send, true)
      Application.put_env(:malan, :email_verification_auto_send, false)

      on_exit(fn ->
        Application.put_env(:malan, :email_verification_auto_send, prev)
      end)

      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, %User{}} =
               Accounts.generate_email_verification(user, rate_limit?: false, context: :resend)
    end

    test ":no_rate_limit skips the rate limit" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, %User{}} = Accounts.generate_email_verification(user, :no_rate_limit)
      # Calling again immediately succeeds (rate limit bypassed)
      assert {:ok, %User{}} = Accounts.generate_email_verification(user, :no_rate_limit)
    end
  end

  describe "validate_email_verification_token/2" do
    test "returns :missing when no token issued" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:error, :missing_email_verification_token} =
               Accounts.validate_email_verification_token(user, "anything")
    end

    test "returns :invalid for wrong token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      assert {:error, :invalid_email_verification_token} =
               Accounts.validate_email_verification_token(user, "not the right token")
    end

    test "returns :ok for valid unexpired token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      assert {:ok} =
               Accounts.validate_email_verification_token(user, user.email_verification_token)
    end

    test "returns :expired when token is past expiration" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      # Force expiration
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      user =
        user
        |> Ecto.Changeset.change(%{email_verification_token_expires_at: past})
        |> Repo.update!()

      assert {:error, :expired_email_verification_token} =
               Accounts.validate_email_verification_token(user, user.email_verification_token)
    end
  end

  describe "verify_email_with_token/2" do
    test "sets email_verified and clears token fields on success" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      assert {:ok, %User{} = updated} =
               Accounts.verify_email_with_token(user, user.email_verification_token)

      refute is_nil(updated.email_verified)
      assert is_nil(updated.email_verification_token_hash)
      assert is_nil(updated.email_verification_token_expires_at)
    end

    test "second verify with same raw token returns :failed_invalid_token (single-use)" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)
      raw = user.email_verification_token

      assert {:ok, _} = Accounts.verify_email_with_token(user, raw)

      assert {:error, :failed_invalid_token} =
               Accounts.verify_email_with_token(user.id, raw)
    end

    test "expired token returns :failed_expired_token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      user =
        user
        |> Ecto.Changeset.change(%{email_verification_token_expires_at: past})
        |> Repo.update!()

      assert {:error, :failed_expired_token} =
               Accounts.verify_email_with_token(user, user.email_verification_token)
    end

    test "atomic conditional update: stale user struct with cleared token fails second verify" do
      # Simulates concurrent-verify: we hold a stale user struct that still has
      # the token, but the atomic UPDATE with WHERE has already cleared the row.
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, stale_user} = Accounts.generate_email_verification(user, :no_rate_limit)
      raw = stale_user.email_verification_token

      # First verifier wins (updates by id and hash)
      assert {:ok, _} = Accounts.verify_email_with_token(stale_user, raw)

      # Second verifier, still holding the stale struct with the now-cleared
      # token hash, gets :failed_invalid_token (0 rows affected).
      assert {:error, :failed_invalid_token} =
               Accounts.verify_email_with_token(stale_user, raw)
    end
  end

  describe "set_email_verified/2 (admin helper)" do
    test "true sets timestamp and clears in-flight token fields" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      assert {:ok, updated} = Accounts.set_email_verified(user, true)
      refute is_nil(updated.email_verified)
      assert is_nil(updated.email_verification_token_hash)
      assert is_nil(updated.email_verification_token_expires_at)
    end

    test "false clears timestamp" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.set_email_verified(user, true)
      refute is_nil(user.email_verified)

      assert {:ok, updated} = Accounts.set_email_verified(user, false)
      assert is_nil(updated.email_verified)
    end

    test "writes an :admin_set audit row" do
      {:ok, user} = Helpers.Accounts.regular_user()

      {:ok, _} = Accounts.set_email_verified(user, true)

      assert [%{event_type: "admin_set"} | _] =
               Repo.all(
                 from e in EmailVerificationEvent,
                   where: e.user_id == ^user.id and e.event_type == "admin_set"
               )
    end
  end

  describe "email change resets verification" do
    test "updating email via admin_update_user clears email_verified and in-flight token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.set_email_verified(user, true)
      refute is_nil(user.email_verified)

      ui = System.unique_integer([:positive])

      {:ok, updated} =
        Accounts.admin_update_user(user, %{"email" => "newemail#{ui}@email.com"})

      assert updated.email == "newemail#{ui}@email.com"
      assert is_nil(updated.email_verified)
    end
  end

  describe "User.skip_email_verification_send?/1" do
    test "matches @example.com" do
      assert User.skip_email_verification_send?("a@example.com")
    end

    test "matches .test TLD suffix" do
      assert User.skip_email_verification_send?("a@foo.test")
    end

    test "does not match regular domain" do
      refute User.skip_email_verification_send?("a@gmail.com")
    end

    test "case-insensitive" do
      assert User.skip_email_verification_send?("a@Example.COM")
    end
  end

  describe "record_email_verification_event/2" do
    test "inserts an event row with user_id and email snapshot" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, event} =
               Accounts.record_email_verification_event(user, %{event_type: "requested"})

      assert event.user_id == user.id
      assert event.email == user.email
      assert event.event_type == "requested"
    end

    test "rejects unknown event_type" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:error, _cs} =
               Accounts.record_email_verification_event(user, %{event_type: "bogus"})
    end
  end
end
