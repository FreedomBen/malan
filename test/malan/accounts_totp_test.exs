defmodule Malan.AccountsTotpTest do
  # async: false — some tests swap the TotpCipher keyring / rate-limit
  # config in Application env
  use Malan.DataCase, async: false

  alias Malan.Accounts
  alias Malan.Accounts.{TotpBackupCode, TotpCipher, UserTotp}
  alias Malan.Test.Helpers

  @ip "192.168.2.200"

  defp verified_user(attrs \\ %{}) do
    {:ok, user} = Helpers.Accounts.regular_user(attrs)
    {:ok, verified} = Accounts.set_email_verified(user, true)
    %{verified | password: user.password}
  end

  defp start_enrollment(user) do
    {:ok, %{secret_base32: b32} = payload} =
      Accounts.start_totp_enrollment(user, user.password, @ip)

    {Base.decode32!(b32, padding: false), payload}
  end

  defp current_code(secret), do: NimbleTOTP.verification_code(secret)

  defp get_totp_row(user), do: Repo.get_by(UserTotp, user_id: user.id)

  describe "start_totp_enrollment/3" do
    test "requires a verified email" do
      {:ok, user} = Helpers.Accounts.regular_user()
      assert is_nil(user.email_verified)

      assert {:error, :email_not_verified} =
               Accounts.start_totp_enrollment(user, user.password, @ip)
    end

    test "requires the correct password" do
      user = verified_user()

      assert {:error, :unauthorized} =
               Accounts.start_totp_enrollment(user, "WrongPassword123", @ip)

      assert {:error, :unauthorized} = Accounts.start_totp_enrollment(user, nil, @ip)
    end

    test "returns provisioning payload and creates a pending enrollment" do
      user = verified_user()
      {secret, payload} = start_enrollment(user)

      assert Map.keys(payload) |> Enum.sort() == [:otpauth_uri, :qr_code_svg, :secret_base32]
      assert byte_size(secret) == 20
      assert payload.otpauth_uri =~ "otpauth://totp/"
      assert payload.otpauth_uri =~ "issuer="
      assert payload.qr_code_svg =~ "<svg"

      assert %{status: :pending, confirmed_at: nil, backup_codes_remaining: 0} =
               Accounts.totp_status(user)

      refute Accounts.totp_enabled?(user)

      # pending rows have no replay guard yet; confirm seeds it
      assert %UserTotp{confirmed_at: nil, last_used_ts: nil} = get_totp_row(user)
    end

    test "embeds the configured issuer in label and query param" do
      user = verified_user()
      {_secret, payload} = start_enrollment(user)
      issuer = URI.encode(Malan.Config.Totp.issuer(), &URI.char_unreserved?/1)

      assert payload.otpauth_uri =~ "otpauth://totp/#{issuer}:"
      assert payload.otpauth_uri =~ "issuer=#{issuer}"
    end

    test "restarting replaces a pending enrollment (old code no longer confirms)" do
      user = verified_user()
      {old_secret, %{secret_base32: old_b32}} = start_enrollment(user)
      {_new_secret, %{secret_base32: new_b32}} = start_enrollment(user)

      assert old_b32 != new_b32

      assert {:error, :invalid_code} =
               Accounts.confirm_totp_enrollment(user, current_code(old_secret), @ip, nil)
    end

    test "refuses when TOTP is already enabled" do
      {:ok, user, _secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      assert {:error, :totp_already_enabled} =
               Accounts.start_totp_enrollment(user, user.password, @ip)
    end
  end

  describe "confirm_totp_enrollment/4" do
    test "with a valid code returns backup codes and enables TOTP" do
      user = verified_user()
      {secret, _} = start_enrollment(user)

      assert {:ok, codes} =
               Accounts.confirm_totp_enrollment(user, current_code(secret), @ip, nil)

      assert length(codes) == 10
      assert Enum.all?(codes, &(byte_size(&1) == 12))
      # codes are unique
      assert codes |> Enum.uniq() |> length() == 10

      assert %{status: :enabled, confirmed_at: %DateTime{}, backup_codes_remaining: 10} =
               Accounts.totp_status(user)

      assert Accounts.totp_enabled?(user)

      # replay guard is seeded with the accepted step's START (step-aligned)
      %UserTotp{last_used_ts: ts} = get_totp_row(user)
      assert is_integer(ts)
      assert rem(ts, 30) == 0
      assert_in_delta ts, System.os_time(:second), 60
    end

    test "rejects an invalid code" do
      user = verified_user()
      {secret, _} = start_enrollment(user)
      wrong = if current_code(secret) == "000000", do: "000001", else: "000000"

      assert {:error, :invalid_code} = Accounts.confirm_totp_enrollment(user, wrong, @ip, nil)
      assert %{status: :pending} = Accounts.totp_status(user)
    end

    test "accepts a code formatted with a space, as authenticator apps display it" do
      user = verified_user()
      {secret, _} = start_enrollment(user)
      code = current_code(secret)
      spaced = String.slice(code, 0, 3) <> " " <> String.slice(code, 3, 3)

      assert {:ok, _codes} = Accounts.confirm_totp_enrollment(user, spaced, @ip, nil)
    end

    test "errors when there is no pending enrollment" do
      user = verified_user()

      assert {:error, :no_pending_enrollment} =
               Accounts.confirm_totp_enrollment(user, "123456", @ip, nil)
    end

    test "errors when TOTP is already confirmed" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      assert {:error, :no_pending_enrollment} =
               Accounts.confirm_totp_enrollment(user, current_code(secret), @ip, nil)
    end
  end

  describe "TOTP code verification (replay, drift, CAS)" do
    test "a code cannot be used twice (sequential replay)" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      code = current_code(secret)

      assert {:ok, _new_codes} =
               Accounts.regenerate_totp_backup_codes(user, user.password, code, @ip)

      assert {:error, :invalid_mfa_code} =
               Accounts.regenerate_totp_backup_codes(user, user.password, code, @ip)
    end

    test "backward replay: a still-in-window previous-step code is rejected after a newer accept" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      # accept the current step N
      assert {:ok, _} =
               Accounts.regenerate_totp_backup_codes(
                 user,
                 user.password,
                 current_code(secret),
                 @ip
               )

      # a code for step N-1 is still inside the drift window but at/below
      # the stored step — reused?/3's `<=` must reject it
      previous =
        NimbleTOTP.verification_code(secret, time: System.os_time(:second) - 30)

      assert {:error, :invalid_mfa_code} =
               Accounts.regenerate_totp_backup_codes(user, user.password, previous, @ip)
    end

    test "drift window: previous step accepted, step before that rejected" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      Helpers.Accounts.rewind_totp_last_used(user, 2)

      two_steps_ago =
        NimbleTOTP.verification_code(secret, time: System.os_time(:second) - 60)

      assert {:error, :invalid_mfa_code} =
               Accounts.regenerate_totp_backup_codes(user, user.password, two_steps_ago, @ip)

      previous =
        NimbleTOTP.verification_code(secret, time: System.os_time(:second) - 30)

      assert {:ok, _} =
               Accounts.regenerate_totp_backup_codes(user, user.password, previous, @ip)
    end

    test "CAS is step-granular: same-step accept updates zero rows and fails" do
      {:ok, user, _secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      %UserTotp{last_used_ts: ts} = totp = get_totp_row(user)

      # same step -> guard's `<` matches nothing -> loser gets an error
      assert {:error, :invalid_mfa_code} = Accounts.cas_totp_last_used_ts(totp, ts)
      # a later step advances the guard
      assert :ok = Accounts.cas_totp_last_used_ts(totp, ts + 30)
      assert %UserTotp{last_used_ts: new_ts} = get_totp_row(user)
      assert new_ts == ts + 30
    end

    test "CAS is nil-safe: a nil guard accepts rather than silently no-oping" do
      user = verified_user()
      {_secret, _} = start_enrollment(user)
      %UserTotp{last_used_ts: nil} = totp = get_totp_row(user)

      now_step = div(System.os_time(:second), 30) * 30
      assert :ok = Accounts.cas_totp_last_used_ts(totp, now_step)
    end

    test "fails closed when the secret cannot be decrypted (key missing from ring)" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      original = Application.fetch_env!(:malan, TotpCipher)

      Application.put_env(:malan, TotpCipher, keys: [{999_999, :crypto.strong_rand_bytes(32)}])

      on_exit(fn -> Application.put_env(:malan, TotpCipher, original) end)

      assert {:error, :invalid_mfa_code} =
               Accounts.regenerate_totp_backup_codes(
                 user,
                 user.password,
                 current_code(secret),
                 @ip
               )
    end
  end

  describe "backup codes" do
    test "a backup code authorizes disable and codes are case-sensitive" do
      {:ok, user, _secret, codes} = Helpers.Accounts.regular_user_with_totp()

      # pin the deliberate absence of case-folding: a case-flipped code is
      # rejected (the flip differs for any code containing a letter)
      code_with_letter = Enum.find(codes, &(&1 =~ ~r/[a-zA-Z]/))

      flipped =
        for <<ch <- code_with_letter>>, into: "" do
          cond do
            ch in ?a..?z -> <<ch - 32>>
            ch in ?A..?Z -> <<ch + 32>>
            true -> <<ch>>
          end
        end

      assert {:error, :invalid_mfa_code} =
               Accounts.disable_totp(user, user.password, flipped, @ip, nil)

      assert {:ok, :disabled} =
               Accounts.disable_totp(user, user.password, code_with_letter, @ip, nil)
    end

    test "backup codes round-trip with whitespace and hyphens" do
      {:ok, user, _secret, [code | _]} = Helpers.Accounts.regular_user_with_totp()

      formatted =
        "  " <>
          String.slice(code, 0, 4) <>
          "-" <> String.slice(code, 4, 4) <> " - " <> String.slice(code, 8, 4) <> "\t"

      assert {:ok, :disabled} = Accounts.disable_totp(user, user.password, formatted, @ip, nil)
    end

    test "regenerating invalidates the old set and decrements nothing on failures" do
      {:ok, user, _secret, [old_code | _] = old_codes} =
        Helpers.Accounts.regular_user_with_totp()

      assert {:ok, new_codes} =
               Accounts.regenerate_totp_backup_codes(user, user.password, old_code, @ip)

      assert length(new_codes) == 10
      assert MapSet.disjoint?(MapSet.new(old_codes), MapSet.new(new_codes))
      assert %{backup_codes_remaining: 10} = Accounts.totp_status(user)

      # every code from the invalidated set is dead, including the one spent
      assert {:error, :invalid_mfa_code} =
               Accounts.disable_totp(user, user.password, old_code, @ip, nil)

      assert {:error, :invalid_mfa_code} =
               Accounts.disable_totp(user, user.password, Enum.at(old_codes, 1), @ip, nil)
    end

    test "spending a backup code marks it used (single-use) and updates remaining count" do
      {:ok, user, secret, [code | _]} = Helpers.Accounts.regular_user_with_totp()

      # spend one code via regenerate authorized by TOTP so the set survives
      assert {:ok, _} =
               Accounts.regenerate_totp_backup_codes(
                 user,
                 user.password,
                 current_code(secret),
                 @ip
               )

      # ^ that replaced the set; use the fresh set for the single-use check
      %{backup_codes_remaining: 10} = Accounts.totp_status(user)

      # disable with wrong password does NOT consume the valid backup code
      assert {:error, :unauthorized} =
               Accounts.disable_totp(user, "WrongPassword123", code, @ip, nil)

      assert %{backup_codes_remaining: 10} = Accounts.totp_status(user)
    end
  end

  describe "disable_totp/5" do
    test "requires password and code, then removes enrollment and backup codes" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      assert {:error, :unauthorized} =
               Accounts.disable_totp(user, "WrongPassword123", current_code(secret), @ip, nil)

      assert {:error, :invalid_mfa_code} =
               Accounts.disable_totp(user, user.password, "000000", @ip, nil)

      # a bad-length code is invalid without consulting either verifier
      assert {:error, :invalid_mfa_code} =
               Accounts.disable_totp(user, user.password, "12345", @ip, nil)

      Helpers.Accounts.rewind_totp_last_used(user)

      assert {:ok, :disabled} =
               Accounts.disable_totp(user, user.password, current_code(secret), @ip, nil)

      assert %{status: :none, backup_codes_remaining: 0} = Accounts.totp_status(user)
      refute Accounts.totp_enabled?(user)
      assert is_nil(get_totp_row(user))
      assert Repo.all(from bc in TotpBackupCode, where: bc.user_id == ^user.id) == []
    end

    test "errors when TOTP is not enabled (no row, or pending only)" do
      user = verified_user()

      assert {:error, :no_totp_enabled} =
               Accounts.disable_totp(user, user.password, "123456", @ip, nil)

      {_secret, _} = start_enrollment(user)

      assert {:error, :no_totp_enabled} =
               Accounts.disable_totp(user, user.password, "123456", @ip, nil)
    end
  end

  describe "admin_disable_totp/3" do
    test "force-disables without password or code and revokes all sessions" do
      {:ok, admin} = Helpers.Accounts.admin_user()
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      {:ok, s1} =
        Helpers.Accounts.create_session(user, %{
          "totp_code" => current_code(secret)
        })

      Helpers.Accounts.rewind_totp_last_used(user)

      {:ok, s2} =
        Helpers.Accounts.create_session(user, %{
          "totp_code" => current_code(secret)
        })

      assert {:ok, :disabled} = Accounts.admin_disable_totp(admin, user, @ip)

      assert %{status: :none} = Accounts.totp_status(user)
      refute Helpers.Accounts.session_valid?(s1.id)
      refute Helpers.Accounts.session_valid?(s2.id)
    end

    test "no-op is an error, not a silent success" do
      {:ok, admin} = Helpers.Accounts.admin_user()
      user = verified_user()

      assert {:error, :no_totp_enabled} = Accounts.admin_disable_totp(admin, user, @ip)

      # a pending enrollment is inert — still nothing enabled to disable
      {_secret, _} = start_enrollment(user)
      assert {:error, :no_totp_enabled} = Accounts.admin_disable_totp(admin, user, @ip)
    end
  end

  describe "session revocation on MFA state change (Decision 4)" do
    test "enabling TOTP revokes other sessions but spares the current one" do
      user = verified_user()
      {:ok, current} = Helpers.Accounts.create_session(user)
      {:ok, other} = Helpers.Accounts.create_session(user)

      {secret, _} = start_enrollment(user)

      assert {:ok, _codes} =
               Accounts.confirm_totp_enrollment(user, current_code(secret), @ip, current.id)

      assert Helpers.Accounts.session_valid?(current.id)
      refute Helpers.Accounts.session_valid?(other.id)
    end

    test "disabling TOTP revokes other sessions but spares the current one" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      {:ok, current} =
        Helpers.Accounts.create_session(user, %{"totp_code" => current_code(secret)})

      Helpers.Accounts.rewind_totp_last_used(user)

      {:ok, other} =
        Helpers.Accounts.create_session(user, %{"totp_code" => current_code(secret)})

      Helpers.Accounts.rewind_totp_last_used(user)

      assert {:ok, :disabled} =
               Accounts.disable_totp(user, user.password, current_code(secret), @ip, current.id)

      assert Helpers.Accounts.session_valid?(current.id)
      refute Helpers.Accounts.session_valid?(other.id)
    end

    test "revoke_active_sessions_except with nil keeps nothing" do
      {:ok, user, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, s2} = Helpers.Accounts.create_session(user)

      assert {:ok, 2} = Accounts.revoke_active_sessions_except(user, @ip, nil)
      refute Helpers.Accounts.session_valid?(s1.id)
      refute Helpers.Accounts.session_valid?(s2.id)
    end
  end

  describe "TotpVerify rate limiting" do
    setup do
      original = Application.fetch_env!(:malan, Malan.Config.RateLimits)

      Application.put_env(
        :malan,
        Malan.Config.RateLimits,
        Keyword.merge(original,
          totp_verify_lower_limit_msecs: 300_000,
          totp_verify_lower_limit_count: 2,
          totp_verify_upper_limit_msecs: 86_400_000,
          totp_verify_upper_limit_count: 1_000_000
        )
      )

      on_exit(fn -> Application.put_env(:malan, Malan.Config.RateLimits, original) end)

      :ok
    end

    test "repeated failures trip the limiter" do
      {:ok, user, _secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      on_exit(fn -> Malan.RateLimits.TotpVerify.clear(user.id) end)

      assert {:error, :unauthorized} =
               Accounts.disable_totp(user, "WrongPassword123", "000000", @ip, nil)

      assert {:error, :unauthorized} =
               Accounts.disable_totp(user, "WrongPassword123", "000000", @ip, nil)

      assert {:error, :too_many_requests} =
               Accounts.disable_totp(user, "WrongPassword123", "000000", @ip, nil)

      # even a correct password + code is refused while throttled
      assert {:error, :too_many_requests} =
               Accounts.disable_totp(user, user.password, "000000", @ip, nil)
    end

    test "successful verification clears the buckets" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      on_exit(fn -> Malan.RateLimits.TotpVerify.clear(user.id) end)

      assert {:error, :invalid_mfa_code} =
               Accounts.regenerate_totp_backup_codes(user, user.password, "000000", @ip)

      # success on the second (and final) slot clears both buckets…
      assert {:ok, _} =
               Accounts.regenerate_totp_backup_codes(
                 user,
                 user.password,
                 current_code(secret),
                 @ip
               )

      # …so two more failures fit before the next deny
      assert {:error, :invalid_mfa_code} =
               Accounts.regenerate_totp_backup_codes(user, user.password, "000000", @ip)

      assert {:error, :invalid_mfa_code} =
               Accounts.regenerate_totp_backup_codes(user, user.password, "000000", @ip)

      assert {:error, :too_many_requests} =
               Accounts.regenerate_totp_backup_codes(user, user.password, "000000", @ip)
    end

    test "enrollment start is charged to the same budget" do
      user = verified_user()
      on_exit(fn -> Malan.RateLimits.TotpVerify.clear(user.id) end)

      assert {:error, :unauthorized} =
               Accounts.start_totp_enrollment(user, "WrongPassword123", @ip)

      assert {:error, :unauthorized} =
               Accounts.start_totp_enrollment(user, "WrongPassword123", @ip)

      assert {:error, :too_many_requests} =
               Accounts.start_totp_enrollment(user, "WrongPassword123", @ip)
    end
  end

  describe "create_session/4 MFA enforcement" do
    test "no confirmed TOTP: a stray totp_code is ignored and login succeeds" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, session} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "123456"})

      assert is_binary(session.api_token)
      assert session.authenticated_by == "password"
    end

    test "client attrs cannot inject authenticated_by" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, session} =
               Helpers.Accounts.create_session(user, %{"authenticated_by" => "password+totp"})

      assert session.authenticated_by == "password"
    end

    test "a pending enrollment does not gate login" do
      user = verified_user()
      {_secret, _} = start_enrollment(user)

      assert {:ok, _session} = Helpers.Accounts.create_session(user)
    end

    test "confirmed TOTP with no code: :mfa_required and no session is created" do
      {:ok, user, _secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      assert {:error, :mfa_required} = Helpers.Accounts.create_session(user)

      # a code that normalizes to the empty string counts as absent
      assert {:error, :mfa_required} =
               Helpers.Accounts.create_session(user, %{"totp_code" => " - "})

      assert Accounts.list_active_sessions(user.id, 0, 10) == []
    end

    test "confirmed TOTP with a wrong code: :invalid_mfa_code" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      wrong = if current_code(secret) == "000000", do: "000001", else: "000000"

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => wrong})

      # bad lengths are invalid without consulting either verifier
      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "12345"})

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "1234567890123"})

      assert Accounts.list_active_sessions(user.id, 0, 10) == []
    end

    test "a valid TOTP code logs in; replaying the same code does not" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      code = current_code(secret)

      assert {:ok, session} = Helpers.Accounts.create_session(user, %{"totp_code" => code})
      assert session.authenticated_by == "password+totp"
      assert Accounts.session_authenticated_by(session.id) == "password+totp"

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => code})
    end

    test "a spaced TOTP code (as authenticator apps display it) logs in" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      code = current_code(secret)
      spaced = String.slice(code, 0, 3) <> " " <> String.slice(code, 3, 3)

      assert {:ok, _session} = Helpers.Accounts.create_session(user, %{"totp_code" => spaced})
    end

    test "a backup code logs in, is single-use, and decrements the remaining count" do
      {:ok, user, _secret, [code | _]} = Helpers.Accounts.regular_user_with_totp()

      assert {:ok, session} = Helpers.Accounts.create_session(user, %{"totp_code" => code})
      assert session.authenticated_by == "password+backup_code"
      assert %{backup_codes_remaining: 9} = Accounts.totp_status(user)

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => code})

      assert %{backup_codes_remaining: 9} = Accounts.totp_status(user)
    end

    test "a hyphen/whitespace-formatted backup code logs in" do
      {:ok, user, _secret, [code | _]} = Helpers.Accounts.regular_user_with_totp()

      formatted =
        String.slice(code, 0, 4) <>
          "-" <> String.slice(code, 4, 4) <> " " <> String.slice(code, 8, 4)

      assert {:ok, _session} = Helpers.Accounts.create_session(user, %{"totp_code" => formatted})
    end

    test "a wrong password is reported before MFA and reveals nothing about codes" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()

      assert {:error, :unauthorized} =
               Accounts.create_session(user.username, "WrongPassword123", @ip, %{
                 "totp_code" => current_code(secret)
               })
    end
  end

  describe "create_session/4 MFA rate limiting" do
    setup do
      original = Application.fetch_env!(:malan, Malan.Config.RateLimits)

      Application.put_env(
        :malan,
        Malan.Config.RateLimits,
        Keyword.merge(original,
          totp_verify_lower_limit_msecs: 300_000,
          totp_verify_lower_limit_count: 2,
          totp_verify_upper_limit_msecs: 86_400_000,
          totp_verify_upper_limit_count: 1_000_000
        )
      )

      on_exit(fn -> Application.put_env(:malan, Malan.Config.RateLimits, original) end)

      :ok
    end

    test "code guessing at login is throttled; supplying no code is not charged" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      on_exit(fn -> Malan.RateLimits.TotpVerify.clear(user.id) end)

      # mfa_required responses never consume budget — nothing was guessed
      for _ <- 1..3 do
        assert {:error, :mfa_required} = Helpers.Accounts.create_session(user)
      end

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "000000"})

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "000000"})

      assert {:error, :too_many_requests} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "000000"})

      # even a valid code is refused while throttled
      assert {:error, :too_many_requests} =
               Helpers.Accounts.create_session(user, %{"totp_code" => current_code(secret)})
    end

    test "a successful login clears the TotpVerify buckets" do
      {:ok, user, secret, _codes} = Helpers.Accounts.regular_user_with_totp()
      on_exit(fn -> Malan.RateLimits.TotpVerify.clear(user.id) end)

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "000000"})

      # success on the final slot clears both buckets…
      assert {:ok, _session} =
               Helpers.Accounts.create_session(user, %{"totp_code" => current_code(secret)})

      # …so two more failures fit before the next deny
      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "000000"})

      assert {:error, :invalid_mfa_code} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "000000"})

      assert {:error, :too_many_requests} =
               Helpers.Accounts.create_session(user, %{"totp_code" => "000000"})
    end
  end

  describe "totp_status/1 and totp_enabled?/1" do
    test "walks none -> pending -> enabled and never leaks secret material" do
      user = verified_user()

      assert %{status: :none, confirmed_at: nil, backup_codes_remaining: 0} =
               Accounts.totp_status(user)

      {secret, _} = start_enrollment(user)
      pending = Accounts.totp_status(user)
      assert %{status: :pending} = pending

      {:ok, _codes} = Accounts.confirm_totp_enrollment(user, current_code(secret), @ip, nil)
      enabled = Accounts.totp_status(user)
      assert %{status: :enabled, backup_codes_remaining: 10} = enabled

      for status_map <- [pending, enabled] do
        assert Map.keys(status_map) |> Enum.sort() ==
                 [:backup_codes_remaining, :confirmed_at, :status]
      end

      # accepts a user id as well as a struct
      assert Accounts.totp_status(user.id) == enabled
      assert Accounts.totp_enabled?(user.id)
    end
  end
end
