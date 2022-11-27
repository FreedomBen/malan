defmodule MalanWeb.LogControllerTest do
  use MalanWeb.ConnCase, async: true

  import Malan.AccountsFixtures

  alias Malan.Accounts.Log

  alias Malan.Test.Helpers
  alias Malan.Test.Utils, as: TestUtils

  def logs_eq?(%{id: _} = l1, %{id: _} = l2) do
    l1.id == l2.id &&
      l1.what == l2.what &&
      l1.type_enum == l2.type_enum &&
      l1.verb_enum == l2.verb_enum
  end

  def logs_eq?(%{"id" => _} = l1, %{id: _} = l2) do
    l1["id"] == l2.id &&
      l1["what"] == l2.what &&
      Log.Type.to_i(l1["type_enum"]) == l2.type_enum &&
      Log.Verb.to_i(l1["verb_enum"]) == l2.verb_enum
  end

  def logs_eq?(%{id: _} = l1, %{"id" => _} = l2) do
    l1.id == l2["id"] &&
      l1.what == l2["what"] &&
      l1.type_enum == Log.Type.to_i(l2["type"]) &&
      l1.verb_enum == Log.Verb.to_i(l2["verb"])
  end

  def logs_eq?(%{"id" => _} = l1, %{"id" => _} = l2) do
    l1["id"] == l2["id"] &&
      l1["what"] == l2["what"] &&
      l1["type"] == l2["type"] &&
      l1["verb"] == l2["verb"]
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "admin_index" do
    test "lists all logs empty", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.log_path(conn, :admin_index))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists all logs", %{conn: conn} do
      {:ok, _u1, _s1, l1} = log_fixture()
      {:ok, _u2, _s2, l2} = log_fixture()

      {:ok, conn, _user, _session} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.log_path(conn, :admin_index))
      [l1a, l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)
      assert logs_eq?(l2, l2a)
    end

    test "requires being an admin", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.log_path(conn, :admin_index))
      assert conn.status == 401
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.log_path(conn, :admin_index))
      assert conn.status == 403
    end

    # Uncomment when ready to enforce ToS and PP for admins
    # test "requires accepting ToS and PP", %{conn: conn} do
    #  {:ok, user, session} = Helpers.Accounts.admin_user_with_session()
    #  conn = Helpers.Accounts.put_token(conn, session.api_token)
    #  conn = get(conn, Routes.log_path(conn, :admin_index))
    #  # We haven't accepted the terms of service yet so expect 461
    #  assert conn.status == 461

    #  {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #  conn = get(conn, Routes.log_path(conn, :admin_index))
    #  # We haven't accepted the PP yet so expect 462
    #  assert conn.status == 462
    # end
  end

  describe "user_index" do
    test "with no user id:  lists all logs for user", %{conn: conn} do
      {:ok, _u1, s1, l1} = log_fixture()
      {:ok, _u2, s2, l2} = log_fixture()

      # First make request as a user that has no logs
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.log_path(conn, :user_index))
      assert json_response(conn, 200)["data"] == []

      # Now make request as user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.log_path(conn, :user_index))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request as user 2
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.log_path(conn, :user_index))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)
    end

    test "with user id and username:  lists all logs for user", %{conn: conn} do
      {:ok, u1, s1, l1} = log_fixture()
      {:ok, u2, s2, l2} = log_fixture()

      # First make request as a user that has no logs
      {:ok, conn, u3, _s3} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.user_log_path(conn, :user_index, u3.id))
      assert json_response(conn, 200)["data"] == []

      # Now make request as user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.user_log_path(conn, :user_index, u1.id))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request as user 2
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_log_path(conn, :user_index, u2.id))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)

      # Now make request as user 1 using username
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.user_log_path(conn, :user_index, u1.username))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request as user 2 using username
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_log_path(conn, :user_index, u2.username))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)
    end

    test "with 'current' as user id:  lists all logs for user", %{conn: _conn} do
      {:ok, _u1, s1, l1} = log_fixture()
      {:ok, _u2, s2, l2} = log_fixture()

      # make request as a user that has no logs
      # {:ok, conn, u3, _s3} = Helpers.Accounts.regular_user_session_conn(conn)
      # conn = get(conn, Routes.user_log_path(conn, :user_index, "current"))
      # assert json_response(conn, 200)["data"] == []

      # Now make request as user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.user_log_path(conn, :user_index, "current"))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request as user 2
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_log_path(conn, :user_index, "current"))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)
    end

    test "user can't list other users logs", %{conn: conn} do
      {:ok, u1, _s1, _l1} = log_fixture()
      {:ok, _u2, s2, _l2} = log_fixture()

      # Now make request as user 2 but for user 1 logs
      conn = Helpers.Accounts.put_token(conn, s2.api_token)
      conn = get(conn, Routes.user_log_path(conn, :user_index, u1.id))
      assert conn.status == 401
    end

    test "admin can list for user", %{conn: conn} do
      {:ok, u1, _s1, l1} = log_fixture()
      {:ok, _u2, _s2, _l2} = log_fixture()

      # Now make request as admin for user 1 logs
      {:ok, conn, _au1, _as4} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.user_log_path(conn, :user_index, u1.id))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)
    end

    test "lists all logs for user empty without id", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.log_path(conn, :user_index))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists all logs for user empty with id", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.user_log_path(conn, :user_index, user.id))
      assert json_response(conn, 200)["data"] == []
    end

    test "requires authentication without user id", %{conn: conn} do
      conn = get(conn, Routes.log_path(conn, :user_index))
      assert conn.status == 403
    end

    test "requires authentication with user id", %{conn: conn} do
      conn = get(conn, Routes.user_log_path(conn, :user_index, "42"))
      assert conn.status == 403
    end

    test "non-existent user id", %{conn: conn} do
      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.user_log_path(conn, :user_index, "notarealuser"))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP without user id", %{conn: conn} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.log_path(conn, :user_index))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.log_path(conn, :user_index))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP with user id", %{conn: conn} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.user_log_path(conn, :user_index, user.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.user_log_path(conn, :user_index, user.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "show" do
    #
    # User version of endpoint
    #

    test "gets log", %{conn: conn} do
      {:ok, _u1, s1, %Log{id: id} = _l1} = log_fixture()
      conn = Helpers.Accounts.put_token(conn, s1.api_token)

      conn = get(conn, Routes.log_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "success" => true,
               "type" => "users",
               "verb" => "GET",
               "what" => "some what",
               "when" => when_str
             } = json_response(conn, 200)["data"]

      assert {:ok, when_utc, 0} = DateTime.from_iso8601(when_str)
      assert TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
    end

    test "requires authentication", %{conn: _} do
      {:ok, _u1, _s1, l1} = log_fixture()
      conn = build_conn()
      conn = get(conn, Routes.log_path(conn, :show, l1.id))
      assert conn.status == 403
    end

    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, %Log{id: id} = _l1} = log_fixture()
    #   conn = Helpers.Accounts.put_token(conn, s1.api_token)

    #   conn = get(conn, Routes.log_path(conn, :show, id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(u1, true)
    #   conn = get(conn, Routes.log_path(conn, :show, id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end

    test "requires being log user to view", %{conn: conn} do
      {:ok, _u1, _s1, l1} = log_fixture()
      {:ok, conn, _u2, _s2} = Helpers.Accounts.regular_user_session_conn(conn)

      conn = get(conn, Routes.log_path(conn, :show, l1.id))
      assert conn.status == 401
    end

    test "allows admin to get log through regular endpoint", %{conn: conn} do
      {:ok, _u1, _s1, %Log{id: id} = _l1} = log_fixture()
      {:ok, conn, _u2, _s2} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = get(conn, Routes.admin_log_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "success" => true,
               "type" => "users",
               "verb" => "GET",
               "what" => "some what",
               "when" => when_str
             } = json_response(conn, 200)["data"]

      assert {:ok, when_utc, 0} = DateTime.from_iso8601(when_str)
      assert TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
    end

    #
    # Admin version of endpoint
    #

    test "allows admin to get log through admin endpoint", %{conn: conn} do
      {:ok, _u1, _s1, %Log{id: id} = _l1} = log_fixture()
      {:ok, conn, _u2, _s2} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = get(conn, Routes.admin_log_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "success" => true,
               "type" => "users",
               "verb" => "GET",
               "what" => "some what",
               "when" => when_str
             } = json_response(conn, 200)["data"]

      assert {:ok, when_utc, 0} = DateTime.from_iso8601(when_str)
      assert TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
    end

    test "disallows regular user through admin endpoint even when user owns it", %{conn: conn} do
      {:ok, _u1, s1, %Log{id: id} = _l1} = log_fixture()
      conn = Helpers.Accounts.put_token(conn, s1.api_token)

      conn = get(conn, Routes.admin_log_path(conn, :show, id))
      assert conn.status == 401
    end

    # test "admin version requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, _u1, s1, %Log{id: id} = _l1} = log_fixture()
    #   {:ok, conn, a1, _s2} = Helpers.Accounts.admin_user_session_conn(conn)

    #   conn = get(conn, Routes.admin_log_path(conn, :show, id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(a1, true)
    #   conn = get(conn, Routes.admin_log_path(conn, :show, id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "users" do
    test "with user id and username:  lists all logs for user", %{conn: _conn} do
      {:ok, u1, _s1, l1} = log_fixture()
      {:ok, u2, _s2, l2} = log_fixture()

      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :users, u1.id))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request for user 2
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :users, u2.id))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)

      # Now make request for user 1 using username
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :users, u1.username))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request for user 2 using username
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :users, u2.username))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.log_path(conn, :user_index))
      assert conn.status == 403
    end

    test "requires being admin", %{conn: _conn} do
      {:ok, u1, s1, _l1} = log_fixture()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.log_path(conn, :users, u1.id))
      assert conn.status == 401
    end

    test "non-existent user", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.log_path(conn, :users, "notarealuser"))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, l1} = log_fixture()
    #   {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.log_path(conn, :users, u1.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.log_path(conn, :users, u1.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "sessions" do
    test "lists all logs for user", %{conn: _conn} do
      {:ok, _u1, s1, l1} = log_fixture()
      {:ok, _u2, s2, l2} = log_fixture()

      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :sessions, s1.id))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request for user 2
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :sessions, s2.id))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.log_path(conn, :sessions, "42"))
      assert conn.status == 403
    end

    test "requires being admin", %{conn: _conn} do
      {:ok, _u1, s1, _l1} = log_fixture()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.log_path(conn, :sessions, s1.id))
      assert conn.status == 401
    end

    test "non-existent session", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.log_path(conn, :sessions, Ecto.UUID.generate()))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, l1} = log_fixture()
    #   {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.log_path(conn, :sessions, s1.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.log_path(conn, :sessions, s1.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "who" do
    test "lists all logs for user", %{conn: _conn} do
      {:ok, u1, _s1, l1} = log_fixture()
      {:ok, u2, _s2, l2} = log_fixture()

      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :who, u1.id))
      [l1a] = json_response(conn, 200)["data"]
      assert logs_eq?(l1, l1a)

      # Now make request for user 2
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.log_path(conn, :who, u2.id))
      [l2a] = json_response(conn, 200)["data"]
      assert logs_eq?(l2, l2a)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.log_path(conn, :who, "42"))
      assert conn.status == 403
    end

    test "requires being admin", %{conn: _conn} do
      {:ok, u1, s1, _l1} = log_fixture()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.log_path(conn, :who, u1.id))
      assert conn.status == 401
    end

    test "non-existent session", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.log_path(conn, :who, Ecto.UUID.generate()))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, l1} = log_fixture()
    #   {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.log_path(conn, :who, u1.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.log_path(conn, :who, u1.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  # defp create_log(_) do
  #   {:ok, user, session, log} = log_fixture()
  #   conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
  #   %{conn: conn, user: user, session: session, log: log}
  # end
end
