defmodule MalanWeb.SessionControllerTest do
  use MalanWeb.ConnCase, async: true

  alias Malan.Utils

  alias Malan.Test.Helpers
  alias Malan.Test.Utils, as: TestUtils

  def datetime_to_string(%DateTime{} = dt) do
    DateTime.to_string(dt)
    |> String.replace(~r/\s/, "T")
  end

  def datetime_to_string(value), do: value

  def session_to_retval_map(session) do
    session
    |> Utils.struct_to_map()
    |> Utils.map_atom_keys_to_strings()
    |> Enum.map(fn {k, v} -> {k, datetime_to_string(v)} end)
    |> Enum.reject(fn {k, _v} -> k == "expires_in_seconds" end)
    |> Enum.reject(fn {k, _v} -> k == "api_token_hash" end)
    |> Enum.reject(fn {k, _v} -> k == "never_expires" end)
    |> Enum.reject(fn {k, _v} -> k == "inserted_at" end)
    |> Enum.reject(fn {k, _v} -> k == "updated_at" end)
    |> Enum.reject(fn {k, _v} -> k == "api_token" end)
    |> Enum.reject(fn {k, _v} -> k == "user" end)
    |> List.insert_at(0, {"is_valid", true})
    |> Enum.into(%{})
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "admin index" do
    test "lists all sessions if user is an admin", %{conn: conn} do
      users = Helpers.Accounts.regular_users_with_session(3)
      {:ok, _ru1, rs1} = List.first(users)
      {:ok, au, as} = Helpers.Accounts.admin_user_with_session()

      conn = get(conn, Routes.session_path(conn, :admin_index))
      assert conn.status == 403

      conn = Helpers.Accounts.put_token(build_conn(), rs1.api_token)
      conn = get(conn, Routes.session_path(conn, :admin_index))
      assert conn.status == 401
      
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.session_path(conn, :admin_index))
      assert conn.status == 461
      # Accept ToS
      {:ok, au} = Helpers.Accounts.accept_user_tos(au, true)
      conn = get(conn, Routes.session_path(conn, :admin_index))
      assert conn.status == 462
      # Accept Privacy Policy
      {:ok, _au} = Helpers.Accounts.accept_user_pp(au, true)
      conn = get(conn, Routes.session_path(conn, :admin_index))
      jr = json_response(conn, 200)["data"]
      assert length(jr) == 4
      assert true == Enum.any?(jr, fn (s) -> s["id"] == as.id end)
      assert true == Enum.any?(jr, fn (s) -> s["id"] == rs1.id end)
    end
  end

  describe "admin delete session" do
    test "deletes chosen session if user is an admin", %{conn: conn} do
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session()
      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = delete(conn, Routes.session_path(conn, :admin_delete, rs.id))
      assert %{"revoked_at" => revoked_at} = json_response(conn, 200)["data"]
      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true
    end

    test "can't be called by non-admin", %{conn: conn} do
      {:ok, conn, _ru, rs} = Helpers.Accounts.regular_user_session_conn(conn)

      conn = delete(conn, Routes.session_path(conn, :admin_delete, rs.id))
      assert conn.status == 401
    end
  end

  describe "index" do
    test "lists all sessions for user", %{conn: conn} do
      # Require authentication
      conn = get(conn, Routes.user_session_path(conn, :index, "some id"))
      assert conn.status == 403

      users = Helpers.Accounts.regular_users_session_conn(build_conn(), 3)
      {:ok, conn, ru1, rs1} = List.first(users)

      conn = get(conn, Routes.user_session_path(conn, :index, ru1.id))
      jr = json_response(conn, 200)["data"]
      assert length(jr) == 1
      assert jr == [session_to_retval_map(rs1)]
    end

    test "can be called by admin non-owner" do
      users = Helpers.Accounts.regular_users_session_conn(build_conn(), 3)
      {:ok, _cr, ru1, rs1} = List.first(users)
      {:ok, ca, _au1, _as1} = Helpers.Accounts.admin_user_session_conn(build_conn())

      ca = get(ca, Routes.user_session_path(ca, :index, ru1.id))
      jr = json_response(ca, 200)["data"]
      assert length(jr) == 1
      assert jr == [session_to_retval_map(rs1)]
    end

    test "can't be called by non-admin non-owner" do
      users = Helpers.Accounts.regular_users_session_conn(build_conn(), 3)
      {:ok, _c1, ru1, _rs1} = Enum.at(users, 0)
      {:ok, c2, _ru2, _rs2} = Enum.at(users, 1)

      c2 = get(c2, Routes.user_session_path(c2, :index, ru1.id))
      assert c2.status == 401
    end
  end

  describe "create session" do
    test "renders session when data is valid", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: user.username, password: user.password})
      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))
      assert conn.status == 403

      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "authenticated_at" => authenticated_at,
               "expires_at" => expires_at,
               "ip_address" => "127.0.0.1",
               "location" => nil,
               "revoked_at" => nil,
               "is_valid" => true,
             } = jr
      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now, authenticated_at, :second))
      assert Enum.member?(0..5, DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second))
    end

    test "invalid username", %{conn: conn} do
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: "invalid username", password: "something wrong"})
      assert true == json_response(conn, 401)["invalid_credentials"]
    end

    test "invalid password", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: user.username, password: "incorrect password"})
      assert true == json_response(conn, 401)["invalid_credentials"]
    end

    test "can be called by admin non-owner", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: user.username, password: user.password})
      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(build_conn())
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "authenticated_at" => authenticated_at,
               "expires_at" => expires_at,
               "ip_address" => "127.0.0.1",
               "location" => nil,
               "revoked_at" => nil,
               "is_valid" => true,
             } = jr
      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now, authenticated_at, :second))
      assert Enum.member?(0..5, DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second))
    end

    test "can't be called by non-admin non-owner", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: user.username, password: user.password})
      assert %{"id" => id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      {:ok, conn, _au, _as} = Helpers.Accounts.regular_user_session_conn(build_conn())
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))
      assert conn.status == 401
    end

    test "Allows creating tokens that never expire", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: user.username, password: user.password, never_expires: true})
      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "authenticated_at" => authenticated_at,
               "expires_at" => expires_at,
               "ip_address" => "127.0.0.1",
               "location" => nil,
               "revoked_at" => nil,
               "is_valid" => true,
             } = jr
      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now, authenticated_at, :second))
      assert Enum.member?(0..5, DateTime.diff(Utils.DateTime.adjust_cur_time(200, :years), expires_at, :second))
    end

    test "Allows specifying token expiration", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: user.username, password: user.password, expires_in_seconds: 60})
      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "authenticated_at" => authenticated_at,
               "expires_at" => expires_at,
               "ip_address" => "127.0.0.1",
               "location" => nil,
               "revoked_at" => nil,
               "is_valid" => true,
             } = jr
      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now, authenticated_at, :second))
      assert Enum.member?(0..5, DateTime.diff(Utils.DateTime.adjust_cur_time(60, :seconds), expires_at, :second))
    end

    test "Ignores if you set User ID or IP address in the parameters", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      conn = post(conn, Routes.session_path(conn, :create), session: %{username: user.username, password: user.password, user_id: "ohia", ip_address: "10.0.0.0"})
      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]
      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "authenticated_at" => authenticated_at,
               "expires_at" => expires_at,
               "ip_address" => "127.0.0.1",
               "location" => nil,
               "revoked_at" => nil,
               "is_valid" => true,
             } = jr
      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now, authenticated_at, :second))
      assert Enum.member?(0..5, DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second))
    end
  end

  describe "delete session" do
    test "deletes chosen session", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))
      assert conn.status == 403
      conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
      conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))
      assert %{
        "revoked_at" => revoked_at,
        "is_valid" => false,
      } = json_response(conn, 200)["data"]
      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true
    end

    test "can be called by admin non-owner", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))
      assert %{"revoked_at" => revoked_at} = json_response(conn, 200)["data"]
      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true
    end

    test "can't be called by non-admin non-owner", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      {:ok, conn, _ru, _rs} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))
      assert conn.status == 401
    end
  end

  #describe "show/valid session" do
  #  test "shows session valid when valid", %{conn: conn} do
  #    {:ok, conn, user, session} = Helpers.Accounts.regular_user_session_conn(conn)
  #    id = session.id
  #    user_id = user.id
  #    conn = get(conn, Routes.user_session_path(conn, :show, user.id, session))
  #    jr = json_response(conn, 200)["data"]
  #    assert %{
  #             "id" => ^id,
  #             "user_id" => ^user_id,
  #             "authenticated_at" => _authenticated_at,
  #             "expires_at" => _expires_at,
  #             "ip_address" => _ip,
  #             "location" => nil,
  #             "revoked_at" => nil
  #           } = jr
  #  end

  #  test "Reports session not valid when invalid", %{conn: conn} do
  #    {:ok, conn, user, session} = Helpers.Accounts.regular_user_session_conn(conn)
  #    conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))
  #    assert %{"revoked_at" => revoked_at} = json_response(conn, 200)["data"]

  #    id = session.id
  #    user_id = user.id
  #    conn = get(conn, Routes.user_session_path(conn, :show, user.id, session))
  #    jr = json_response(conn, 200)["data"]
  #    assert %{
  #             "id" => ^id,
  #             "user_id" => ^user_id,
  #             "authenticated_at" => _authenticated_at,
  #             "expires_at" => _expires_at,
  #             "ip_address" => _ip,
  #             "location" => nil,
  #             "revoked_at" => ^revoked_at,
  #           } = jr
  #  end

  #  test "non-owner cannot check session validitiy" do

  #  end
  #end
end
