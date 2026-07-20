defmodule MalanWeb.TotpControllerTest do
  use MalanWeb.ConnCase, async: true

  alias Malan.Accounts
  alias Malan.Test.Helpers

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # Authed conn for a user with confirmed TOTP; password virtual retained.
  # The replay guard is rewound after the login so tests can immediately
  # use the current step's code.
  defp totp_user_conn(conn) do
    {:ok, user, secret, backup_codes} = Helpers.Accounts.regular_user_with_totp()

    {:ok, session} =
      Helpers.Accounts.create_session(user, %{
        "totp_code" => NimbleTOTP.verification_code(secret)
      })

    Helpers.Accounts.rewind_totp_last_used(user)
    {Helpers.Accounts.put_token(conn, session.api_token), user, secret, backup_codes, session}
  end

  # Authed conn for a verified-email user with no TOTP yet
  defp verified_user_conn(conn) do
    {:ok, user} = Helpers.Accounts.regular_user()
    {:ok, verified} = Accounts.set_email_verified(user, true)
    user = %{verified | password: user.password}
    {:ok, session} = Helpers.Accounts.create_session(user)
    {Helpers.Accounts.put_token(conn, session.api_token), user, session}
  end

  defp current_code(secret), do: NimbleTOTP.verification_code(secret)

  describe "show (GET /api/users/:user_id/totp)" do
    test "walks none -> pending -> enabled and never discloses secret material", %{conn: conn} do
      {conn, user, _session} = verified_user_conn(conn)

      resp = get(conn, Routes.user_totp_path(conn, :show, user.id)) |> json_response(200)
      assert %{"ok" => true, "data" => %{"status" => "none"}} = resp

      # start an enrollment -> pending
      post(conn, Routes.user_totp_path(conn, :create, user.id), password: user.password)
      pending = get(conn, Routes.user_totp_path(conn, :show, user.id)) |> json_response(200)
      assert %{"data" => %{"status" => "pending", "confirmed_at" => nil} = data} = pending

      # the whole reason the password gate on POST is not bypassable:
      # GET must never return the secret, otpauth URI, or QR — pending or not
      assert Map.keys(data) |> Enum.sort() ==
               ["backup_codes_remaining", "confirmed_at", "status"]

      # the "current" path segment resolves to the authed user
      assert get(conn, Routes.user_totp_path(conn, :show, "current"))
             |> json_response(200)
             |> get_in(["data", "status"]) == "pending"
    end

    test "enabled status discloses only status fields", %{conn: conn} do
      {conn, user, _secret, _codes, _session} = totp_user_conn(conn)

      resp = get(conn, Routes.user_totp_path(conn, :show, user.id)) |> json_response(200)

      assert %{
               "ok" => true,
               "data" =>
                 %{
                   "status" => "enabled",
                   "confirmed_at" => confirmed_at,
                   "backup_codes_remaining" => 10
                 } = data
             } = resp

      assert is_binary(confirmed_at)

      assert Map.keys(data) |> Enum.sort() ==
               ["backup_codes_remaining", "confirmed_at", "status"]
    end

    test "a non-owner cannot view; an admin can", %{conn: conn} do
      {_conn, user, _secret, _codes, _session} = totp_user_conn(build_conn())

      {:ok, other_conn, _other_user, _s} = Helpers.Accounts.regular_user_session_conn(conn)
      other_conn = get(other_conn, Routes.user_totp_path(other_conn, :show, user.id))
      assert other_conn.status == 401

      {:ok, admin_conn, _admin, _as} = Helpers.Accounts.admin_user_session_conn(build_conn())
      admin_conn = get(admin_conn, Routes.user_totp_path(admin_conn, :show, user.id))
      assert %{"data" => %{"status" => "enabled"}} = json_response(admin_conn, 200)
    end

    test "unauthenticated request is refused", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      conn = get(conn, Routes.user_totp_path(conn, :show, user.id))
      assert conn.status == 403
    end
  end

  describe "create (POST /api/users/:user_id/totp)" do
    test "starts enrollment with the correct password", %{conn: conn} do
      {conn, user, _session} = verified_user_conn(conn)

      resp =
        post(conn, Routes.user_totp_path(conn, :create, user.id), password: user.password)
        |> json_response(201)

      assert %{
               "ok" => true,
               "data" => %{
                 "secret_base32" => secret_base32,
                 "otpauth_uri" => "otpauth://totp/" <> _,
                 "qr_code_svg" => "<" <> _
               }
             } = resp

      assert {:ok, secret} = Base.decode32(secret_base32, padding: false)
      assert byte_size(secret) == 20
    end

    test "requires the password (Decision 3): missing or wrong -> generic 403", %{conn: conn} do
      {conn, user, _session} = verified_user_conn(conn)

      no_pass = post(conn, Routes.user_totp_path(conn, :create, user.id))
      body = json_response(no_pass, 403)
      assert body["message"] =~ "password"
      refute Map.has_key?(body, "invalid_mfa_code")
      refute Map.has_key?(body, "mfa_required")

      wrong =
        post(conn, Routes.user_totp_path(conn, :create, user.id), password: "WrongPassword123")

      assert json_response(wrong, 403)["message"] =~ "password"

      # no pending row was created by the failed attempts
      assert get(conn, Routes.user_totp_path(conn, :show, user.id))
             |> json_response(200)
             |> get_in(["data", "status"]) == "none"
    end

    test "requires a verified email", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, session} = Helpers.Accounts.create_session(user)
      conn = Helpers.Accounts.put_token(conn, session.api_token)

      resp = post(conn, Routes.user_totp_path(conn, :create, user.id), password: user.password)

      assert json_response(resp, 403)["message"] =~ "verified"
    end

    test "returns 409 (a real 409 body) when TOTP is already enabled", %{conn: conn} do
      {conn, user, _secret, _codes, _session} = totp_user_conn(conn)

      resp = post(conn, Routes.user_totp_path(conn, :create, user.id), password: user.password)

      # pins the dedicated ErrorJSON clause — template_not_found/2 would
      # emit a body that says 404
      assert %{"ok" => false, "code" => 409, "detail" => "Conflict"} = json_response(resp, 409)
    end
  end

  describe "confirm (PUT /api/users/:user_id/totp/confirm)" do
    test "full flow: enroll -> confirm -> backup codes -> MFA-gated login", %{conn: conn} do
      {conn, user, _session} = verified_user_conn(conn)

      %{"data" => %{"secret_base32" => b32}} =
        post(conn, Routes.user_totp_path(conn, :create, user.id), password: user.password)
        |> json_response(201)

      secret = Base.decode32!(b32, padding: false)

      %{"ok" => true, "data" => %{"backup_codes" => backup_codes}} =
        put(conn, Routes.user_totp_path(conn, :confirm, user.id), code: current_code(secret))
        |> json_response(200)

      assert length(backup_codes) == 10
      assert Enum.all?(backup_codes, &(byte_size(&1) == 12))

      # login now requires the code…
      no_code =
        post(build_conn(), Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"mfa_required" => true} = json_response(no_code, 403)

      # …and succeeds with one (previous step: confirm consumed the current)
      Helpers.Accounts.rewind_totp_last_used(user)

      with_code =
        post(build_conn(), Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            totp_code: current_code(secret)
          }
        )

      assert %{"api_token" => _} = json_response(with_code, 201)["data"]
    end

    test "an invalid code gets the invalid_mfa_code body", %{conn: conn} do
      {conn, user, _session} = verified_user_conn(conn)
      post(conn, Routes.user_totp_path(conn, :create, user.id), password: user.password)

      resp = put(conn, Routes.user_totp_path(conn, :confirm, user.id), code: "000000")

      assert %{
               "invalid_mfa_code" => true,
               "mfa_required" => true,
               "mfa_types" => ["totp"],
               "errors" => [%{"totp_code" => ["invalid"]}]
             } = json_response(resp, 403)
    end

    test "404 when there is no pending enrollment", %{conn: conn} do
      {conn, user, _session} = verified_user_conn(conn)

      resp = put(conn, Routes.user_totp_path(conn, :confirm, user.id), code: "123456")
      assert %{"ok" => false, "code" => 404} = json_response(resp, 404)
    end
  end

  describe "disable (POST /api/users/:user_id/totp/disable)" do
    test "requires password + code, then disables and revokes other sessions", %{conn: conn} do
      {conn, user, secret, _codes, current_session} = totp_user_conn(conn)

      {:ok, other_session} =
        Helpers.Accounts.create_session(user, %{"totp_code" => current_code(secret)})

      Helpers.Accounts.rewind_totp_last_used(user)

      wrong_pass =
        post(conn, Routes.user_totp_path(conn, :disable, user.id),
          password: "WrongPassword123",
          code: current_code(secret)
        )

      body = json_response(wrong_pass, 403)
      assert body["message"] =~ "password"
      refute Map.has_key?(body, "invalid_mfa_code")

      wrong_code =
        post(conn, Routes.user_totp_path(conn, :disable, user.id),
          password: user.password,
          code: "000000"
        )

      assert %{"invalid_mfa_code" => true} = json_response(wrong_code, 403)

      ok =
        post(conn, Routes.user_totp_path(conn, :disable, user.id),
          password: user.password,
          code: current_code(secret)
        )

      assert %{"ok" => true, "data" => %{"status" => "none"}} = json_response(ok, 200)

      assert Helpers.Accounts.session_valid?(current_session.id)
      refute Helpers.Accounts.session_valid?(other_session.id)
    end

    test "accepts a backup code in place of a TOTP code", %{conn: conn} do
      {conn, user, _secret, [backup_code | _], _session} = totp_user_conn(conn)

      ok =
        post(conn, Routes.user_totp_path(conn, :disable, user.id),
          password: user.password,
          code: backup_code
        )

      assert %{"data" => %{"status" => "none"}} = json_response(ok, 200)
    end

    test "404 when TOTP is not enabled", %{conn: conn} do
      {conn, user, _session} = verified_user_conn(conn)

      resp =
        post(conn, Routes.user_totp_path(conn, :disable, user.id),
          password: user.password,
          code: "123456"
        )

      assert json_response(resp, 404)
    end
  end

  describe "regenerate (POST /api/users/:user_id/totp/backup_codes)" do
    test "mints a fresh set with password + code (Decision 8)", %{conn: conn} do
      {conn, user, secret, old_codes, _session} = totp_user_conn(conn)

      no_pass =
        post(conn, Routes.user_totp_path(conn, :regenerate_backup_codes, user.id),
          code: current_code(secret)
        )

      assert json_response(no_pass, 403)["message"] =~ "password"

      resp =
        post(conn, Routes.user_totp_path(conn, :regenerate_backup_codes, user.id),
          password: user.password,
          code: current_code(secret)
        )

      assert %{"ok" => true, "data" => %{"backup_codes" => new_codes}} = json_response(resp, 200)
      assert length(new_codes) == 10
      assert MapSet.disjoint?(MapSet.new(old_codes), MapSet.new(new_codes))
    end
  end

  describe "admin force-disable (DELETE /api/admin/users/:id/totp)" do
    test "disables without password/code and revokes all target sessions", %{conn: conn} do
      {_owner_conn, user, secret, _codes, owner_session} = totp_user_conn(build_conn())

      {:ok, other_session} =
        Helpers.Accounts.create_session(user, %{"totp_code" => current_code(secret)})

      {:ok, admin_conn, _admin, _as} = Helpers.Accounts.admin_user_session_conn(conn)

      resp = delete(admin_conn, Routes.totp_path(admin_conn, :admin_delete, user.id))
      assert %{"ok" => true, "data" => %{"status" => "none"}} = json_response(resp, 200)

      # recovery path spares nothing — all of the target's sessions die
      refute Helpers.Accounts.session_valid?(owner_session.id)
      refute Helpers.Accounts.session_valid?(other_session.id)

      # and the user can log in without a code again
      login =
        post(build_conn(), Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"api_token" => _} = json_response(login, 201)["data"]
    end

    test "404 when the target has no enabled TOTP", %{conn: conn} do
      {:ok, target} = Helpers.Accounts.regular_user()
      {:ok, admin_conn, _admin, _as} = Helpers.Accounts.admin_user_session_conn(conn)

      resp = delete(admin_conn, Routes.totp_path(admin_conn, :admin_delete, target.id))
      assert json_response(resp, 404)
    end

    test "a non-admin cannot use the admin route", %{conn: conn} do
      {_owner_conn, user, _secret, _codes, _session} = totp_user_conn(build_conn())
      {:ok, other_conn, _other, _s} = Helpers.Accounts.regular_user_session_conn(conn)

      other_conn = delete(other_conn, Routes.totp_path(other_conn, :admin_delete, user.id))
      assert other_conn.status == 401
    end
  end

  describe "user JSON exposure" do
    test "user show and whoami report totp_enabled", %{conn: conn} do
      {conn, _user, _secret, _codes, _session} = totp_user_conn(conn)

      # /api/users/current flows through user_data/1
      show = get(conn, Routes.user_path(conn, :current)) |> json_response(200)
      assert show["data"]["totp_enabled"] == true

      # whoami builds a session-shaped map and needs its own lookup
      whoami = get(conn, Routes.user_path(conn, :whoami)) |> json_response(200)
      assert whoami["data"]["totp_enabled"] == true

      {:ok, plain_conn, _plain_user, _s} =
        Helpers.Accounts.regular_user_session_conn(build_conn())

      plain_show = get(plain_conn, Routes.user_path(plain_conn, :current)) |> json_response(200)
      assert plain_show["data"]["totp_enabled"] == false
    end
  end
end
