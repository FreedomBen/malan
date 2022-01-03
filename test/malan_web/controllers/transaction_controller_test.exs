defmodule MalanWeb.TransactionControllerTest do
  use MalanWeb.ConnCase

  import Malan.AccountsFixtures

  alias Malan.Accounts.Transaction

  alias Malan.Test.Helpers
  alias Malan.Test.Utils, as: TestUtils

  def transactions_eq?(%{id: _} = t1, %{id: _} = t2) do
    t1.id == t2.id &&
      t1.what == t2.what &&
      t1.type_enum == t2.type_enum &&
      t1.verb_enum == t2.verb_enum
  end

  def transactions_eq?(%{"id" => _} = t1, %{id: _} = t2) do
    t1["id"] == t2.id &&
      t1["what"] == t2.what &&
      Transaction.Type.to_i(t1["type_enum"]) == t2.type_enum &&
      Transaction.Verb.to_i(t1["verb_enum"]) == t2.verb_enum
  end

  def transactions_eq?(%{id: _} = t1, %{"id" => _} = t2) do
    t1.id == t2["id"] &&
      t1.what == t2["what"] &&
      t1.type_enum == Transaction.Type.to_i(t2["type"]) &&
      t1.verb_enum == Transaction.Verb.to_i(t2["verb"])
  end

  def transactions_eq?(%{"id" => _} = t1, %{"id" => _} = t2) do
    t1["id"] == t2["id"] &&
      t1["what"] == t2["what"] &&
      t1["type"] == t2["type"] &&
      t1["verb"] == t2["verb"]
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "admin_index" do
    test "lists all transactions empty", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.transaction_path(conn, :admin_index))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists all transactions", %{conn: conn} do
      {:ok, _u1, _s1, t1} = transaction_fixture()
      {:ok, _u2, _s2, t2} = transaction_fixture()

      {:ok, conn, _user, _session} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.transaction_path(conn, :admin_index))
      [t1a, t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)
      assert transactions_eq?(t2, t2a)
    end

    test "requires being an admin", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.transaction_path(conn, :admin_index))
      assert conn.status == 401
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :admin_index))
      assert conn.status == 403
    end

    # Uncomment when ready to enforce ToS and PP for admins
    # test "requires accepting ToS and PP", %{conn: conn} do
    #  {:ok, user, session} = Helpers.Accounts.admin_user_with_session()
    #  conn = Helpers.Accounts.put_token(conn, session.api_token)
    #  conn = get(conn, Routes.transaction_path(conn, :admin_index))
    #  # We haven't accepted the terms of service yet so expect 461
    #  assert conn.status == 461

    #  {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #  conn = get(conn, Routes.transaction_path(conn, :admin_index))
    #  # We haven't accepted the PP yet so expect 462
    #  assert conn.status == 462
    # end
  end

  describe "user_index" do
    test "with no user id:  lists all transactions for user", %{conn: conn} do
      {:ok, _u1, s1, t1} = transaction_fixture()
      {:ok, _u2, s2, t2} = transaction_fixture()

      # First make request as a user that has no transactions
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.transaction_path(conn, :user_index))
      assert json_response(conn, 200)["data"] == []

      # Now make request as user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.transaction_path(conn, :user_index))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request as user 2
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.transaction_path(conn, :user_index))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)
    end

    test "with user id and username:  lists all transactions for user", %{conn: conn} do
      {:ok, u1, s1, t1} = transaction_fixture()
      {:ok, u2, s2, t2} = transaction_fixture()

      # First make request as a user that has no transactions
      {:ok, conn, u3, _s3} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, u3.id))
      assert json_response(conn, 200)["data"] == []

      # Now make request as user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, u1.id))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request as user 2
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, u2.id))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)

      # Now make request as user 1 using username
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, u1.username))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request as user 2 using username
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, u2.username))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)
    end

    test "with 'current' as user id:  lists all transactions for user", %{conn: _conn} do
      {:ok, _u1, s1, t1} = transaction_fixture()
      {:ok, _u2, s2, t2} = transaction_fixture()

      # make request as a user that has no transactions
      #{:ok, conn, u3, _s3} = Helpers.Accounts.regular_user_session_conn(conn)
      #conn = get(conn, Routes.user_transaction_path(conn, :user_index, "current"))
      #assert json_response(conn, 200)["data"] == []

      # Now make request as user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, "current"))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request as user 2
      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, "current"))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)
    end

    test "user can't list other users transactions", %{conn: conn} do
      {:ok, u1, _s1, _t1} = transaction_fixture()
      {:ok, _u2, s2, _t2} = transaction_fixture()

      # Now make request as user 2 but for user 1 transactions
      conn = Helpers.Accounts.put_token(conn, s2.api_token)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, u1.id))
      assert conn.status == 401
    end

    test "admin can list for user", %{conn: conn} do
      {:ok, u1, _s1, t1} = transaction_fixture()
      {:ok, _u2, _s2, _t2} = transaction_fixture()

      # Now make request as admin for user 1 transactions
      {:ok, conn, _au1, _as4} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, u1.id))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)
    end

    test "lists all transactions for user empty without id", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.transaction_path(conn, :user_index))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists all transactions for user empty with id", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, user.id))
      assert json_response(conn, 200)["data"] == []
    end

    test "requires authentication without user id", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :user_index))
      assert conn.status == 403
    end

    test "requires authentication with user id", %{conn: conn} do
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, "42"))
      assert conn.status == 403
    end

    test "non-existent user id", %{conn: conn} do
      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(conn)
      conn = get(conn, Routes.user_transaction_path(conn, :user_index, "notarealuser"))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP without user id", %{conn: conn} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.transaction_path(conn, :user_index))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.transaction_path(conn, :user_index))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP with user id", %{conn: conn} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.user_transaction_path(conn, :user_index, user.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.user_transaction_path(conn, :user_index, user.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "show" do

    #
    # User version of endpoint
    #

    test "gets transaction", %{conn: conn} do
      {:ok, _u1, s1, %Transaction{id: id} = _t1} = transaction_fixture()
      conn = Helpers.Accounts.put_token(conn, s1.api_token)

      conn = get(conn, Routes.transaction_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "type" => "users",
               "verb" => "GET",
               "what" => "some what",
               "when" => when_str,
             } = json_response(conn, 200)["data"]

      assert {:ok, when_utc, 0} = DateTime.from_iso8601(when_str)
      assert TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
    end

    test "requires authentication", %{conn: _} do
      {:ok, _u1, _s1, t1} = transaction_fixture()
      conn = build_conn()
      conn = get(conn, Routes.transaction_path(conn, :show, t1.id))
      assert conn.status == 403
    end

    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, %Transaction{id: id} = _t1} = transaction_fixture()
    #   conn = Helpers.Accounts.put_token(conn, s1.api_token)

    #   conn = get(conn, Routes.transaction_path(conn, :show, id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(u1, true)
    #   conn = get(conn, Routes.transaction_path(conn, :show, id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end

    test "requires being transaction user to view", %{conn: conn} do
      {:ok, _u1, _s1, t1} = transaction_fixture()
      {:ok, conn, _u2, _s2} = Helpers.Accounts.regular_user_session_conn(conn)

      conn = get(conn, Routes.transaction_path(conn, :show, t1.id))
      assert conn.status == 401
    end

    test "allows admin to get transaction through regular endpoint", %{conn: conn} do
      {:ok, _u1, _s1, %Transaction{id: id} = _t1} = transaction_fixture()
      {:ok, conn, _u2, _s2} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = get(conn, Routes.admin_transaction_path(conn, :show, id))

      assert %{
               "id" => ^id,
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

    test "allows admin to get transaction through admin endpoint", %{conn: conn} do
      {:ok, _u1, _s1, %Transaction{id: id} = _t1} = transaction_fixture()
      {:ok, conn, _u2, _s2} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = get(conn, Routes.admin_transaction_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "type" => "users",
               "verb" => "GET",
               "what" => "some what",
               "when" => when_str
             } = json_response(conn, 200)["data"]

      assert {:ok, when_utc, 0} = DateTime.from_iso8601(when_str)
      assert TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
    end

    test "disallows regular user through admin endpoint even when user owns it", %{conn: conn} do
      {:ok, _u1, s1, %Transaction{id: id} = _t1} = transaction_fixture()
      conn = Helpers.Accounts.put_token(conn, s1.api_token)

      conn = get(conn, Routes.admin_transaction_path(conn, :show, id))
      assert conn.status == 401
    end

    # test "admin version requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, _u1, s1, %Transaction{id: id} = _t1} = transaction_fixture()
    #   {:ok, conn, a1, _s2} = Helpers.Accounts.admin_user_session_conn(conn)

    #   conn = get(conn, Routes.admin_transaction_path(conn, :show, id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(a1, true)
    #   conn = get(conn, Routes.admin_transaction_path(conn, :show, id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "users" do
    test "with user id and username:  lists all transactions for user", %{conn: _conn} do
      {:ok, u1, _s1, t1} = transaction_fixture()
      {:ok, u2, _s2, t2} = transaction_fixture()

      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :users, u1.id))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request for user 2
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :users, u2.id))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)

      # Now make request for user 1 using username
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :users, u1.username))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request for user 2 using username
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :users, u2.username))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :user_index))
      assert conn.status == 403
    end

    test "requires being admin", %{conn: _conn} do
      {:ok, u1, s1, _t1} = transaction_fixture()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.transaction_path(conn, :users, u1.id))
      assert conn.status == 401
    end

    test "non-existent user", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :users, "notarealuser"))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, t1} = transaction_fixture()
    #   {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.transaction_path(conn, :users, u1.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.transaction_path(conn, :users, u1.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "sessions" do
    test "lists all transactions for user", %{conn: _conn} do
      {:ok, _u1, s1, t1} = transaction_fixture()
      {:ok, _u2, s2, t2} = transaction_fixture()

      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :sessions, s1.id))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request for user 2
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :sessions, s2.id))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :sessions, "42"))
      assert conn.status == 403
    end

    test "requires being admin", %{conn: _conn} do
      {:ok, _u1, s1, _t1} = transaction_fixture()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.transaction_path(conn, :sessions, s1.id))
      assert conn.status == 401
    end

    test "non-existent session", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :sessions, Ecto.UUID.generate()))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, t1} = transaction_fixture()
    #   {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.transaction_path(conn, :sessions, s1.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.transaction_path(conn, :sessions, s1.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "who" do
    test "lists all transactions for user", %{conn: _conn} do
      {:ok, u1, _s1, t1} = transaction_fixture()
      {:ok, u2, _s2, t2} = transaction_fixture()

      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :who, u1.id))
      [t1a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t1, t1a)

      # Now make request for user 2
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :who, u2.id))
      [t2a] = json_response(conn, 200)["data"]
      assert transactions_eq?(t2, t2a)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :who, "42"))
      assert conn.status == 403
    end

    test "requires being admin", %{conn: _conn} do
      {:ok, u1, s1, _t1} = transaction_fixture()

      # Now make request for user 1
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.transaction_path(conn, :who, u1.id))
      assert conn.status == 401
    end

    test "non-existent session", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()
      conn = Helpers.Accounts.put_token(conn, as.api_token)
      conn = get(conn, Routes.transaction_path(conn, :who, Ecto.UUID.generate()))
      assert json_response(conn, 200)["data"] == []
    end

    # Uncomment when ready to require ToS and PP
    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, u1, s1, t1} = transaction_fixture()
    #   {:ok, user, session} = Helpers.Accounts.admin_user_with_session()

    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.transaction_path(conn, :who, u1.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.transaction_path(conn, :who, u1.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  #defp create_transaction(_) do
  #  {:ok, user, session, transaction} = transaction_fixture()
  #  conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
  #  %{conn: conn, user: user, session: session, transaction: transaction}
  #end
end
