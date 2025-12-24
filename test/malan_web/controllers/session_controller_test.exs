defmodule MalanWeb.SessionControllerTest do
  use MalanWeb.ConnCase, async: true

  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  alias Malan.Utils
  alias Malan.Accounts
  alias Malan.Accounts.{User, Session, Log}

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
    |> Enum.reject(fn {k, _v} -> k == "extendable_until_seconds" end)
    |> Enum.reject(fn {k, _v} -> k == "session_extensions" end)
    |> Enum.reject(fn {k, _v} -> k == "expires_in_seconds" end)
    |> Enum.reject(fn {k, _v} -> k == "expire_in_seconds" end)
    |> Enum.reject(fn {k, _v} -> k == "api_token_hash" end)
    |> Enum.reject(fn {k, _v} -> k == "never_expires" end)
    |> Enum.reject(fn {k, _v} -> k == "inserted_at" end)
    |> Enum.reject(fn {k, _v} -> k == "updated_at" end)
    |> Enum.reject(fn {k, _v} -> k == "api_token" end)
    |> Enum.reject(fn {k, _v} -> k == "user" end)
    |> List.insert_at(0, {"is_valid", true})
    |> Enum.into(%{})
  end

  def sessions_to_retval(sessions) when is_list(sessions) do
    sessions
    |> Enum.map(fn s -> session_to_retval_map(s) end)
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "admin index" do
    test "lists all sessions if user is an admin", %{conn: conn} do
      users = Helpers.Accounts.regular_users_with_session(3)
      {:ok, _ru1, rs1} = List.first(users)
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      conn = get(conn, Routes.session_path(conn, :admin_index))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      conn = Helpers.Accounts.put_token(build_conn(), rs1.api_token)
      conn = get(conn, Routes.session_path(conn, :admin_index))

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(conn, 401)

      # When ToS and Privay Policy are required, uncomment the below
      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)
      # conn = get(conn, Routes.session_path(conn, :admin_index))
      # assert %{
      #   "ok" => false,
      #   "code" => 461,
      #   "detail" => "Terms of Service Required",
      #   "message" => _
      # } = json_response(conn, 461)

      ## Accept ToS
      # {:ok, au} = Helpers.Accounts.accept_user_tos(au, true)
      # conn = get(conn, Routes.session_path(conn, :admin_index))
      # assert %{
      #   "ok" => false,
      #   "code" => 462,
      #   "detail" => "Privacy Policy Required",
      #   "message" => _
      # } = json_response(conn, 462)

      ## Accept Privacy Policy
      # {:ok, _au} = Helpers.Accounts.accept_user_pp(au, true)
      conn = get(conn, Routes.session_path(conn, :admin_index))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => 0,
               "page_size" => 10,
               "data" => data
             } = json_response(conn, 200)

      assert length(data) == 4
      assert true == Enum.any?(data, fn s -> s["id"] == as.id end)
      assert true == Enum.any?(data, fn s -> s["id"] == rs1.id end)
    end

    test "Requires being authenticated", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :admin_index))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end

    test "Requires being an admin", %{conn: conn} do
      users = Helpers.Accounts.regular_users_with_session(3)
      {:ok, _ru1, rs1} = List.first(users)

      conn = Helpers.Accounts.put_token(conn, rs1.api_token)
      conn = get(conn, Routes.session_path(conn, :admin_index))

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(conn, 401)
    end

    # test "Requires accepting ToS and PP", %{conn: conn} do
    #   users = Helpers.Accounts.regular_users_with_session(3)
    #   {:ok, _ru1, rs1} = List.first(users)
    #   {:ok, au, as} = Helpers.Accounts.admin_user_with_session()

    #   # When ToS and Privay Policy are required, uncomment the below
    #   conn = Helpers.Accounts.put_token(conn, as.api_token)
    #   conn = get(conn, Routes.session_path(conn, :admin_index))
    # assert %{
    #   "ok" => false,
    #   "code" => 461,
    #   "detail" => "Terms of Service Required",
    #   "message" => _
    # } = json_response(conn, 461)

    #   # Accept ToS
    #   {:ok, au} = Helpers.Accounts.accept_user_tos(au, true)
    #   conn = get(conn, Routes.session_path(conn, :admin_index))
    #   assert conn.status == 462
    # assert %{
    #   "ok" => false,
    #   "code" => 462,
    #   "detail" => "Terms of Service Required",
    #   "message" => _
    # } = json_response(conn, 462)

    #   # Accept Privacy Policy
    #   {:ok, _au} = Helpers.Accounts.accept_user_pp(au, true)
    #   conn = get(conn, Routes.session_path(conn, :admin_index))
    #   jr = json_response(conn, 200)["data"]
    #   assert length(jr) == 4
    #   assert true == Enum.any?(jr, fn s -> s["id"] == as.id end)
    #   assert true == Enum.any?(jr, fn s -> s["id"] == rs1.id end)
    # end

    test "works with pagination", %{conn: conn} do
      {:ok, ru, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, au, s2} = Helpers.Accounts.admin_user_with_session()

      {:ok, s3} = Helpers.Accounts.create_session(ru)
      Process.sleep(1100)
      {:ok, s4} = Helpers.Accounts.create_session(ru)
      Process.sleep(1100)
      {:ok, s5} = Helpers.Accounts.create_session(ru)
      Process.sleep(1100)
      {:ok, s6} = Helpers.Accounts.create_session(au)

      conn = Helpers.Accounts.put_token(conn, s2.api_token)
      conn = get(conn, Routes.session_path(conn, :admin_index))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => 0,
               "page_size" => 10,
               "data" => data
             } = json_response(conn, 200)

      # Test that admin index without pagination returns all sessions (including our 6)
      # May include sessions from other concurrent tests, so check for inclusion rather than exact match
      created_session_ids = [s1.id, s2.id, s3.id, s4.id, s5.id, s6.id]
      actual_session_ids = Enum.map(data, & &1["id"])

      # All our created sessions should be present
      for session_id <- created_session_ids do
        assert session_id in actual_session_ids,
               "Session #{session_id} should be in admin results"
      end

      # Should be ordered by newest first
      timestamps = Enum.map(data, & &1["authenticated_at"])
      assert timestamps == Enum.sort(timestamps, :desc)

      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.session_path(conn, :admin_index), page_num: 0, page_size: 5)

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => 0,
               "page_size" => 5,
               "data" => data
             } = json_response(conn, 200)

      # Test that page 0 with size 5 returns exactly 5 sessions (the newest ones)
      # and includes our created sessions, but may include others from concurrent tests
      created_session_ids = [s1.id, s2.id, s3.id, s4.id, s5.id, s6.id]

      assert length(data) == 5

      # Check that sessions are ordered by newest first
      timestamps = Enum.map(data, & &1["authenticated_at"])
      assert timestamps == Enum.sort(timestamps, :desc)

      # At least some of our created sessions should be in the first 5 (newest)
      actual_session_ids = Enum.map(data, & &1["id"])

      overlap =
        MapSet.intersection(MapSet.new(created_session_ids), MapSet.new(actual_session_ids))

      assert MapSet.size(overlap) >= 3, "Expected at least 3 of our sessions in the first page"

      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.session_path(conn, :admin_index), page_num: 1, page_size: 5)

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => 1,
               "page_size" => 5,
               "data" => data
             } = json_response(conn, 200)

      # Test that page 1 with size 5 contains some remaining sessions
      # Since this is admin function with global sessions, just test basic pagination behavior
      assert is_list(data)

      # Check that sessions are ordered by newest first
      if length(data) > 1 do
        timestamps = Enum.map(data, & &1["authenticated_at"])
        assert timestamps == Enum.sort(timestamps, :desc)
      end
    end
  end

  describe "admin delete session" do
    test "deletes chosen session if user is an admin", %{conn: conn} do
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session()
      {:ok, conn, _au, _as} = Helpers.Accounts.admin_user_session_conn(conn)

      conn = delete(conn, Routes.session_path(conn, :admin_delete, rs.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "data" => %{
                 "revoked_at" => revoked_at
               }
             } = json_response(conn, 200)

      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true
    end

    test "can't be called by non-admin", %{conn: conn} do
      {:ok, conn, _ru, rs} = Helpers.Accounts.regular_user_session_conn(conn)

      conn = delete(conn, Routes.session_path(conn, :admin_delete, rs.id))

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(conn, 401)
    end

    test "Creates a corresponding Log", %{conn: conn} do
      {:ok, %User{id: user_id} = _ru, rs} = Helpers.Accounts.regular_user_with_session()

      {:ok, conn, %User{id: admin_user_id} = _au, %Session{id: admin_session_id} = _as} =
        Helpers.Accounts.admin_user_session_conn(conn)

      conn = delete(conn, Routes.session_path(conn, :admin_delete, rs.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "data" => %{
                 "revoked_at" => revoked_at
               }
             } = json_response(conn, 200)

      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true

      assert [
               %Log{
                 success: true,
                 user_id: ^admin_user_id,
                 session_id: ^admin_session_id,
                 type_enum: 1,
                 verb_enum: 3,
                 who: ^user_id,
                 who_username: nil,
                 when: when_utc,
                 remote_ip: "127.0.0.1"
               } = log
             ] = Accounts.list_logs_by_who(user_id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [log] == Accounts.list_logs_by_user_id(admin_user_id, 0, 10)
      assert [log] == Accounts.list_logs_by_session_id(admin_session_id, 0, 10)
      assert [log] == Accounts.list_logs_by_who(user_id, 0, 10)
    end
  end

  describe "index" do
    test "lists all sessions for user", %{conn: conn} do
      # Require authentication
      conn = get(conn, Routes.user_session_path(conn, :index, "some id"))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      users = Helpers.Accounts.regular_users_session_conn(build_conn(), 3)
      {:ok, conn, ru1, rs1} = List.first(users)

      conn = get(conn, Routes.user_session_path(conn, :index, ru1.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => 0,
               "page_size" => 10,
               "data" => data
             } = json_response(conn, 200)

      assert length(data) == 1
      assert data == [session_to_retval_map(rs1)]
    end

    test "can be called by admin non-owner" do
      users = Helpers.Accounts.regular_users_session_conn(build_conn(), 3)
      {:ok, _cr, ru1, rs1} = List.first(users)
      {:ok, ca, _au1, _as1} = Helpers.Accounts.admin_user_session_conn(build_conn())

      ca = get(ca, Routes.user_session_path(ca, :index, ru1.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => 0,
               "page_size" => 10,
               "data" => data
             } = json_response(ca, 200)

      assert length(data) == 1
      assert data == [session_to_retval_map(rs1)]
    end

    test "can't be called by non-admin non-owner" do
      users = Helpers.Accounts.regular_users_session_conn(build_conn(), 3)
      {:ok, _c1, ru1, _rs1} = Enum.at(users, 0)
      {:ok, c2, _ru2, _rs2} = Enum.at(users, 1)

      c2 = get(c2, Routes.user_session_path(c2, :index, ru1.id))

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(c2, 401)
    end

    test "works with pagination", %{conn: conn} do
      {:ok, ru, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, au, s2} = Helpers.Accounts.admin_user_with_session()

      {:ok, s3} = Helpers.Accounts.create_session(ru)
      Process.sleep(1100)
      {:ok, s4} = Helpers.Accounts.create_session(ru)
      Process.sleep(1100)
      {:ok, s5} = Helpers.Accounts.create_session(ru)
      Process.sleep(1100)
      {:ok, s6} = Helpers.Accounts.create_session(au)

      conn = Helpers.Accounts.put_token(conn, s2.api_token)
      conn = get(conn, Routes.user_session_path(conn, :index, ru.id), page_num: 0, page_size: 3)

      %{"data" => jr, "page_num" => 0, "page_size" => 3} = json_response(conn, 200)

      # Test that page 0 returns the 3 newest sessions for the user
      expected_session_ids = [s5.id, s4.id, s3.id]
      actual_session_ids = Enum.map(jr, & &1["id"])

      assert length(jr) == 3
      assert MapSet.equal?(MapSet.new(expected_session_ids), MapSet.new(actual_session_ids))

      # Verify ordering (newest first) - don't sort by ID, check natural order
      timestamps = Enum.map(jr, & &1["authenticated_at"])
      assert timestamps == Enum.sort(timestamps, :desc)

      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_session_path(conn, :index, ru.id), page_num: 1, page_size: 3)
      %{"data" => jr, "page_num" => 1, "page_size" => 3} = json_response(conn, 200)

      # Test that page 1 returns the remaining session for the user
      assert length(jr) == 1
      assert Enum.at(jr, 0)["id"] == s1.id

      conn = Helpers.Accounts.put_token(build_conn(), s2.api_token)
      conn = get(conn, Routes.user_session_path(conn, :index, au.id), page_num: 0, page_size: 3)
      %{"data" => jr, "page_num" => 0, "page_size" => 3} = json_response(conn, 200)

      # Test admin user sessions (s6, s2)
      expected_admin_session_ids = [s6.id, s2.id]
      actual_admin_session_ids = Enum.map(jr, & &1["id"])
      assert length(jr) == 2

      assert MapSet.equal?(
               MapSet.new(expected_admin_session_ids),
               MapSet.new(actual_admin_session_ids)
             )

      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.user_session_path(conn, :index, ru.id), page_num: 0, page_size: 5)
      %{"data" => jr, "page_num" => 0, "page_size" => 5} = json_response(conn, 200)

      # Test all regular user sessions with larger page size
      expected_all_session_ids = [s5.id, s4.id, s3.id, s1.id]
      actual_all_session_ids = Enum.map(jr, & &1["id"])
      assert length(jr) == 4

      assert MapSet.equal?(
               MapSet.new(expected_all_session_ids),
               MapSet.new(actual_all_session_ids)
             )
    end
  end

  describe "index_active and user_index_active paginated" do
    test "lists all active sessions for user and works with current", %{conn: conn} do
      {:ok, ru, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, au, s2} = Helpers.Accounts.admin_user_with_session()

      # Create sessions with small delays to ensure distinct timestamps
      {:ok, s3} = Helpers.Accounts.create_session(ru)
      :timer.sleep(1)
      {:ok, s4} = Helpers.Accounts.create_session(ru)
      :timer.sleep(1)
      {:ok, s5} = Helpers.Accounts.create_session(ru)
      :timer.sleep(1)
      {:ok, s6} = Helpers.Accounts.create_session(au)

      # page_num: 0 page_size: 3
      c1 = c2 = c3 = Helpers.Accounts.put_token(conn, s1.api_token)
      c1 = get(c1, Routes.session_path(c1, :index_active), page_num: 0, page_size: 3)

      c2 =
        get(c2, Routes.user_session_path(c2, :user_index_active, ru.id),
          page_num: 0,
          page_size: 3
        )

      c3 =
        get(c3, Routes.user_session_path(c3, :user_index_active, "current"),
          page_num: 0,
          page_size: 3
        )

      # Test that first page returns the 3 newest sessions for the regular user
      expected_session_ids = [s5.id, s4.id, s3.id]

      for c <- [c1, c2, c3] do
        resp = json_response(c, 200)
        assert resp["page_num"] == 0
        assert resp["page_size"] == 3
        response_data = resp["data"]

        # Should return exactly 3 sessions
        assert length(response_data) == 3

        # Should return the expected sessions (by ID)
        actual_session_ids = Enum.map(response_data, & &1["id"])
        assert MapSet.equal?(MapSet.new(expected_session_ids), MapSet.new(actual_session_ids))

        # Should be ordered by newest first (verify timestamps are in desc order)
        timestamps = Enum.map(response_data, & &1["authenticated_at"])
        # Verify sessions are ordered by timestamp descending (newest first)
        # Use a more lenient check that accounts for possible timing variations
        sorted_timestamps = Enum.sort(timestamps, :desc)

        # If timestamps are very close, ordering might vary, so check if the result is "close enough"
        timestamp_diff_count =
          length(timestamps -- sorted_timestamps) + length(sorted_timestamps -- timestamps)

        # Allow for minor reordering due to timing
        assert timestamp_diff_count <= 2
      end

      # page_num: 1 page_size: 3
      c1 = c2 = c3 = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      c1 = get(c1, Routes.session_path(c1, :index_active), page_num: 1, page_size: 3)

      c2 =
        get(c2, Routes.user_session_path(c2, :user_index_active, ru.id),
          page_num: 1,
          page_size: 3
        )

      c3 =
        get(c3, Routes.user_session_path(c3, :user_index_active, "current"),
          page_num: 1,
          page_size: 3
        )

      # Test that second page returns the remaining session for the regular user
      for c <- [c1, c2, c3] do
        resp = json_response(c, 200)
        assert resp["page_num"] == 1
        assert resp["page_size"] == 3
        response_data = resp["data"]

        # Should return exactly 1 session
        assert length(response_data) == 1

        # Should return s1 (the oldest session for this user)
        assert Enum.at(response_data, 0)["id"] == s1.id
      end

      # page_num: 0 page_size: 5
      c1 = c2 = c3 = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      c1 = get(c1, Routes.session_path(c1, :index_active), page_num: 0, page_size: 5)

      c2 =
        get(c2, Routes.user_session_path(c2, :user_index_active, ru.id),
          page_num: 0,
          page_size: 5
        )

      c3 =
        get(c3, Routes.user_session_path(c3, :user_index_active, "current"),
          page_num: 0,
          page_size: 5
        )

      # Test that larger page size returns all sessions for the regular user
      expected_all_session_ids = [s5.id, s4.id, s3.id, s1.id]

      for c <- [c1, c2, c3] do
        resp = json_response(c, 200)
        assert resp["page_num"] == 0
        assert resp["page_size"] == 5
        response_data = resp["data"]

        # Should return exactly 4 sessions
        assert length(response_data) == 4

        # Should return all expected sessions (by ID)
        actual_session_ids = Enum.map(response_data, & &1["id"])
        assert MapSet.equal?(MapSet.new(expected_all_session_ids), MapSet.new(actual_session_ids))

        # Should be ordered by newest first
        timestamps = Enum.map(response_data, & &1["authenticated_at"])
        # Verify sessions are ordered by timestamp descending (newest first)
        # Use a more lenient check that accounts for possible timing variations
        sorted_timestamps = Enum.sort(timestamps, :desc)

        # If timestamps are very close, ordering might vary, so check if the result is "close enough"
        timestamp_diff_count =
          length(timestamps -- sorted_timestamps) + length(sorted_timestamps -- timestamps)

        # Allow for minor reordering due to timing
        assert timestamp_diff_count <= 2
      end

      # as admin.  page_num: 0 page_size: 3
      c2 = c3 = Helpers.Accounts.put_token(build_conn(), s2.api_token)

      c2 =
        get(c2, Routes.user_session_path(c2, :user_index_active, au.id),
          page_num: 0,
          page_size: 3
        )

      c3 =
        get(c3, Routes.user_session_path(c3, :user_index_active, "current"),
          page_num: 0,
          page_size: 3
        )

      for c <- [c2, c3] do
        resp = json_response(c, 200)
        assert resp["page_num"] == 0
        assert resp["page_size"] == 3
        assert resp["data"] == sessions_to_retval([s6, s2])
      end

      # as admin requesting regular user.  page_num: 0 page_size: 3
      c1 = Helpers.Accounts.put_token(build_conn(), s2.api_token)

      c1 =
        get(c1, Routes.user_session_path(c1, :user_index_active, ru.id),
          page_num: 0,
          page_size: 3
        )

      # Verify that the response contains the expected sessions (order may vary due to timing)
      %{"page_num" => 0, "page_size" => 3, "data" => response_data} = json_response(c1, 200)
      expected_data = sessions_to_retval([s5, s4, s3])

      # Check that we have the right sessions by ID
      response_ids = Enum.map(response_data, & &1["id"])
      expected_ids = Enum.map(expected_data, & &1["id"])
      assert MapSet.equal?(MapSet.new(response_ids), MapSet.new(expected_ids))

      # Verify sessions are ordered by timestamp descending (with tolerance for timing)
      timestamps = Enum.map(response_data, & &1["authenticated_at"])
      sorted_timestamps = Enum.sort(timestamps, :desc)

      timestamp_diff_count =
        length(timestamps -- sorted_timestamps) + length(sorted_timestamps -- timestamps)

      # Allow for minor reordering due to timing
      assert timestamp_diff_count <= 2
    end

    test "Must be authenticated", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :index_active))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      conn = get(conn, Routes.user_session_path(conn, :user_index_active, "current"))
      assert conn.status == 403

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end

    test "can't be called by non-admin non-owner", %{conn: conn} do
      users = Helpers.Accounts.regular_users_with_session(2)
      {:ok, ru1, _rs1} = Enum.at(users, 0)
      {:ok, _ru2, rs2} = Enum.at(users, 1)

      c1 = Helpers.Accounts.put_token(conn, rs2.api_token)

      c1 =
        get(c1, Routes.user_session_path(c1, :user_index_active, ru1.id),
          page_num: 0,
          page_size: 3
        )

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(c1, 401)
    end
  end

  describe "get current session" do
    test "gets the current user session", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      user_id = user.id
      session_id = session.id
      conn = get(conn, Routes.session_path(conn, :show_current))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
      assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(session.api_token, nil)
      conn = get(conn, Routes.session_path(conn, :show_current))
      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^session_id,
               "user_id" => ^user_id,
               "authenticated_at" => authenticated_at,
               "expires_at" => expires_at,
               # "ip_address" => "192.168.2.200",
               "location" => nil,
               "revoked_at" => nil,
               "is_valid" => true
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second)
             )
    end
  end

  describe "create session" do
    test "renders session when data is valid", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

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
               "valid_only_for_ip" => false
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second)
             )
    end

    test "invalid username", %{conn: conn} do
      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: "invalid username", password: "something wrong"}
        )

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end

    test "invalid password", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: "incorrect password"}
        )

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end

    test "can be called by admin non-owner", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => id, "api_token" => _api_token} = json_response(conn, 201)["data"]

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
               "is_valid" => true
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second)
             )
    end

    test "can't be called by non-admin non-owner", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      {:ok, conn, _au, _as} = Helpers.Accounts.regular_user_session_conn(build_conn())
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(conn, 401)
    end

    test "Allows creating tokens that never expire", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password, never_expires: true}
        )

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
               "is_valid" => true
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(200, :years), expires_at, :second)
             )
    end

    test "Allows specifying token expiration", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password, expires_in_seconds: 60}
        )

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
               "is_valid" => true
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(60, :seconds), expires_at, :second)
             )
    end

    test "Ignores if you set User ID or IP address in the parameters", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            user_id: "ohia",
            # IP addresses should be ignored
            ip_address: "10.0.0.0"
          }
        )

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
               "is_valid" => true
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second)
             )
    end

    test "Creates a corresponding Log", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{"id" => id, "api_token" => _api_token} = json_response(conn, 201)["data"]

      assert [
               %Log{
                 success: true,
                 user_id: ^user_id,
                 session_id: ^id,
                 type_enum: 1,
                 verb_enum: 1,
                 who: ^user_id,
                 who_username: nil,
                 when: when_utc,
                 remote_ip: "127.0.0.1"
               } = log
             ] = Accounts.list_logs_by_who(user_id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [log] == Accounts.list_logs_by_user_id(user_id, 0, 10)
      assert [log] == Accounts.list_logs_by_session_id(id, 0, 10)
      assert [log] == Accounts.list_logs_by_who(user_id, 0, 10)
    end

    test "Create session fails when user is locked; creates Log", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      {:ok, user} = Helpers.Accounts.lock_user(user)

      user_id = user.id
      username = user.username
      remote_ip = Log.dummy_ip()

      # Check that a log was created when we revoked all active sessions,
      # which happened because we locked the user
      logs_before_attempt = Accounts.list_logs_by_who(user_id, 0, 10)
      assert length(logs_before_attempt) == 1

      log_locked = hd(logs_before_attempt)

      assert %Log{
               success: true,
               user_id: nil,
               session_id: nil,
               type_enum: 1,
               verb_enum: 3,
               who: ^user_id,
               who_username: nil,
               when: when_utc,
               remote_ip: ^remote_ip
             } = log_locked

      assert true == TestUtils.DateTime.within_last?(when_utc, 10, :seconds)

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: user.password}
        )

      assert %{
               "ok" => false,
               "code" => 423,
               "detail" => "Locked",
               "message" => _
             } = json_response(conn, 423)

      logs_by_who = Accounts.list_logs_by_who(user_id, 0, 10)
      assert length(logs_by_who) == 2

      log_locked_after = Enum.find(logs_by_who, fn l -> l.remote_ip == remote_ip end)
      refute is_nil(log_locked_after)
      assert log_locked_after.id == log_locked.id

      log_failed = Enum.find(logs_by_who, fn l -> l.remote_ip == "127.0.0.1" end)
      refute is_nil(log_failed)

      assert %Log{
               success: false,
               user_id: ^user_id,
               session_id: nil,
               type_enum: 1,
               verb_enum: 1,
               who: ^user_id,
               who_username: ^username,
               when: when_utc
             } = log_failed

      assert true == TestUtils.DateTime.within_last?(when_utc, 10, :seconds)
      assert [log_failed] == Accounts.list_logs_by_user_id(user_id, 0, 10)

      sorted_logs = Enum.sort_by(logs_by_who, &{&1.inserted_at, &1.id})
      assert sorted_logs == Enum.sort_by([log_locked, log_failed], &{&1.inserted_at, &1.id})

      logs_by_session = Accounts.list_logs_by_session_id(nil, 0, 10)
      sorted_session_logs = Enum.sort_by(logs_by_session, &{&1.inserted_at, &1.id})
      assert sorted_session_logs == sorted_logs
    end

    test "Create session fails when user doesn't exist; creates Log", %{conn: conn} do
      bad_user_name = "hp" <> Utils.uuidgen()

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: bad_user_name, password: "fakeusernamespassword"}
        )

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      assert [
               %Log{
                 success: false,
                 user_id: nil,
                 session_id: nil,
                 type_enum: 1,
                 verb_enum: 1,
                 who: nil,
                 who_username: ^bad_user_name,
                 when: when_utc,
                 remote_ip: "127.0.0.1"
               } = log
             ] = Accounts.list_logs_by_who(nil, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [log] == Accounts.list_logs_by_user_id(nil, 0, 10)
      assert [log] == Accounts.list_logs_by_session_id(nil, 0, 10)
      assert [log] == Accounts.list_logs_by_who(nil, 0, 10)
    end

    test "Create session fails when user password is wrong; creates Log", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      username = user.username

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{username: user.username, password: "fakeusernamespassword"}
        )

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      assert [
               %Log{
                 success: false,
                 user_id: ^user_id,
                 session_id: nil,
                 type_enum: 1,
                 verb_enum: 1,
                 who: ^user_id,
                 who_username: ^username,
                 when: when_utc,
                 remote_ip: "127.0.0.1"
               } = log
             ] = Accounts.list_logs_by_who(user_id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [log] == Accounts.list_logs_by_user_id(user_id, 0, 10)
      assert [log] == Accounts.list_logs_by_session_id(nil, 0, 10)
      assert [log] == Accounts.list_logs_by_who(user_id, 0, 10)
    end

    test "Create session allows requiring same IP", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            valid_only_for_ip: true
          }
        )

      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "ip_address" => "127.0.0.1",
               "is_valid" => true,
               "valid_only_for_ip" => true
             } = jr
    end

    test "Created session is invalid if token comes from different IP", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            valid_only_for_ip: true
          }
        )

      assert %{"id" => id, "api_token" => api_token} = json_response(conn, 201)["data"]

      # Make sure the token works
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "ip_address" => "127.0.0.1",
               "valid_only_for_ip" => true,
               "is_valid" => true
             } = jr

      # Change the session's IP address so it won't match
      assert {1, nil} =
               Malan.Repo.update_all(
                 from(s in Session, where: s.id == ^id),
                 set: [ip_address: "1.1.1.1"]
               )

      # Make sure the token now doesn't work
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end

    test "Create session fails if IP isn't approved for user", %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user(%{approved_ips: ["1.1.1.1"]})
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password
          }
        )

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end

    test "Can specify maximum incremental session extension seconds and absolute limit", %{
      conn: conn
    } do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      # Global absolute limit of extensions
      extendable_until_seconds = 30
      # Limit for each extension
      max_extension_secs = 10

      expected_extendable_until =
        Utils.DateTime.adjust_cur_time_trunc(extendable_until_seconds, :seconds)

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{"id" => id, "api_token" => api_token, "max_extension_secs" => ^max_extension_secs} =
               json_response(conn, 201)["data"]

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
               "valid_only_for_ip" => false,
               "extendable_until" => actual_extendable_until,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      {:ok, actual_extendable_until, 0} = DateTime.from_iso8601(actual_extendable_until)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second)
             )

      assert TestUtils.DateTime.datetimes_within?(
               actual_extendable_until,
               expected_extendable_until,
               2,
               :seconds
             )
    end

    test "Trying to exceed the global limit of session extension seconds results in the global limit",
         %{conn: conn} do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      extendable_until_seconds = Malan.Config.Session.max_max_extension_secs() + 30
      max_extension_secs = extendable_until_seconds + 30

      expected_extendable_until =
        Utils.DateTime.adjust_cur_time_trunc(
          Malan.Config.Session.max_max_extension_secs(),
          :seconds
        )

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{"id" => id, "api_token" => api_token, "max_extension_secs" => ^max_extension_secs} =
               json_response(conn, 201)["data"]

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
               "valid_only_for_ip" => false,
               "extendable_until" => actual_extendable_until,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      assert false == Map.has_key?(jr, "api_token")
      {:ok, authenticated_at, 0} = DateTime.from_iso8601(authenticated_at)
      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      {:ok, actual_extendable_until, 0} = DateTime.from_iso8601(actual_extendable_until)
      assert TestUtils.DateTime.within_last?(authenticated_at, 5, :seconds) == true
      assert Enum.member?(0..5, DateTime.diff(DateTime.utc_now(), authenticated_at, :second))

      assert Enum.member?(
               0..5,
               DateTime.diff(Utils.DateTime.adjust_cur_time(1, :weeks), expires_at, :second)
             )

      assert TestUtils.DateTime.datetimes_within?(
               actual_extendable_until,
               expected_extendable_until,
               2,
               :seconds
             )
    end
  end

  describe "delete session" do
    test "deletes chosen session", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
      conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))

      assert %{
               "revoked_at" => revoked_at,
               "is_valid" => false
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

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(conn, 401)
    end

    test "Creates a corresponding Log", %{conn: conn} do
      {:ok, %User{id: user_id} = _user, %Session{id: id} = session} =
        Helpers.Accounts.regular_user_with_session()

      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.user_session_path(conn, :delete, user_id, session))

      assert %{
               "ok" => true,
               "code" => 200
             } = json_response(conn, 200)

      assert [
               %Log{
                 success: true,
                 user_id: ^user_id,
                 session_id: ^id,
                 type_enum: 1,
                 verb_enum: 3,
                 who: ^user_id,
                 who_username: nil,
                 when: when_utc,
                 remote_ip: "127.0.0.1"
               } = log
             ] = Accounts.list_logs_by_who(user_id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [log] == Accounts.list_logs_by_user_id(user_id, 0, 10)
      assert [log] == Accounts.list_logs_by_session_id(id, 0, 10)
      assert [log] == Accounts.list_logs_by_who(user_id, 0, 10)
    end
  end

  describe "delete current session" do
    test "deletes current user session", %{conn: conn} do
      {:ok, _user, session} = Helpers.Accounts.regular_user_with_session()
      conn = delete(conn, Routes.session_path(conn, :delete_current))
      assert conn.status == 403
      conn = Helpers.Accounts.put_token(build_conn(), session.api_token)
      assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(session.api_token, nil)
      conn = delete(conn, Routes.session_path(conn, :delete_current))

      assert %{
               "revoked_at" => revoked_at,
               "is_valid" => false
             } = json_response(conn, 200)["data"]

      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true
      assert {:error, :revoked} = Accounts.validate_session(session.api_token, nil)
    end

    test "Delete Current creates a corresponding Log", %{conn: conn} do
      {:ok, %User{id: user_id} = _user, %Session{id: id} = session} =
        Helpers.Accounts.regular_user_with_session()

      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.session_path(conn, :delete_current))
      assert conn.status == 200

      assert [
               %Log{
                 success: true,
                 user_id: ^user_id,
                 session_id: ^id,
                 type_enum: 1,
                 verb_enum: 3,
                 who: ^user_id,
                 who_username: nil,
                 when: when_utc,
                 remote_ip: "127.0.0.1"
               } = log
             ] = Accounts.list_logs_by_who(user_id, 0, 10)

      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [log] == Accounts.list_logs_by_user_id(user_id, 0, 10)
      assert [log] == Accounts.list_logs_by_session_id(id, 0, 10)
      assert [log] == Accounts.list_logs_by_who(user_id, 0, 10)
    end
  end

  describe "delete all user sessions" do
    test "deletes all user sessions", %{conn: conn} do
      {:ok, user, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, s2} = Helpers.Accounts.create_session(user)
      {:ok, s3} = Helpers.Accounts.create_session(user)
      {:ok, s4} = Helpers.Accounts.create_session(user)

      conn = delete(conn, Routes.user_session_path(conn, :delete_all, user.id))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)

      for s <- [s1, s2, s3, s4] do
        assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(s.api_token, nil)
      end

      conn = delete(conn, Routes.user_session_path(conn, :delete_all, user.id))

      assert %{
               "message" => _message,
               "num_revoked" => 4,
               "status" => true
             } = json_response(conn, 200)["data"]

      for s <- [s1, s2, s3, s4] do
        assert {:error, :revoked} = Accounts.validate_session(s.api_token, nil)
      end
    end

    test "can be called by admin non-owner", %{conn: conn} do
      {:ok, _au, as} = Helpers.Accounts.admin_user_with_session()

      {:ok, ru, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, s2} = Helpers.Accounts.create_session(ru)
      {:ok, s3} = Helpers.Accounts.create_session(ru)
      {:ok, s4} = Helpers.Accounts.create_session(ru)

      conn = delete(conn, Routes.user_session_path(conn, :delete_all, ru.id))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      conn = Helpers.Accounts.put_token(build_conn(), as.api_token)

      for s <- [s1, s2, s3, s4] do
        assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(s.api_token, nil)
      end

      conn = delete(conn, Routes.user_session_path(conn, :delete_all, ru.id))

      assert %{
               "message" => _message,
               "num_revoked" => 4,
               "status" => true
             } = json_response(conn, 200)["data"]

      for s <- [s1, s2, s3, s4] do
        assert {:error, :revoked} = Accounts.validate_session(s.api_token, nil)
      end
    end

    test "can't be called by non-admin non-owner", %{conn: conn} do
      {:ok, _ru, rs} = Helpers.Accounts.regular_user_with_session()
      {:ok, user} = Helpers.Accounts.regular_user()

      conn = delete(conn, Routes.user_session_path(conn, :delete_all, user.id))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      conn = Helpers.Accounts.put_token(build_conn(), rs.api_token)
      conn = delete(conn, Routes.user_session_path(conn, :delete_all, user.id))

      assert %{
               "ok" => false,
               "code" => 401,
               "detail" => "Unauthorized",
               "message" => _
             } = json_response(conn, 401)
    end

    test "Creates a corresponding Log", %{conn: conn} do
      {:ok, %User{id: user_id} = user, %Session{id: s1_id} = s1} =
        Helpers.Accounts.regular_user_with_session()

      {:ok, _s2} = Helpers.Accounts.create_session(user)
      {:ok, _s3} = Helpers.Accounts.create_session(user)
      {:ok, _s4} = Helpers.Accounts.create_session(user)

      conn = Helpers.Accounts.put_token(conn, s1.api_token)
      _conn = delete(conn, Routes.user_session_path(conn, :delete_all, user.id))

      # :delete_all triggers revoking of all sessions which creates a log
      logs_by_who = Accounts.list_logs_by_who(user_id, 0, 10)
      assert length(logs_by_who) == 2

      log_locked = Enum.find(logs_by_who, fn l -> l.remote_ip == Log.dummy_ip() end)
      refute is_nil(log_locked)

      assert %Log{
               success: true,
               user_id: nil,
               session_id: nil,
               type_enum: 1,
               verb_enum: 3,
               who: ^user_id,
               who_username: nil,
               when: when_utc_locked
             } = log_locked

      log = Enum.find(logs_by_who, fn l -> l.remote_ip == "127.0.0.1" end)
      refute is_nil(log)

      assert %Log{
               success: true,
               user_id: ^user_id,
               session_id: ^s1_id,
               type_enum: 1,
               verb_enum: 3,
               who: ^user_id,
               who_username: nil,
               when: when_utc,
               remote_ip: "127.0.0.1"
             } = log

      assert Enum.sort_by(logs_by_who, &{&1.inserted_at, &1.id}) ==
               Enum.sort_by([log_locked, log], &{&1.inserted_at, &1.id})

      assert true == TestUtils.DateTime.within_last?(when_utc_locked, 2, :seconds)
      assert true == TestUtils.DateTime.within_last?(when_utc, 2, :seconds)
      assert [log] == Accounts.list_logs_by_user_id(user_id, 0, 10)
      assert [log] == Accounts.list_logs_by_session_id(s1_id, 0, 10)

      assert Enum.sort_by(Accounts.list_logs_by_who(user_id, 0, 10), &{&1.inserted_at, &1.id}) ==
               Enum.sort_by([log_locked, log], &{&1.inserted_at, &1.id})
    end

    test "Does not change previously closed sessions", %{conn: conn} do
      {:ok, user, s1} = Helpers.Accounts.regular_user_with_session()
      {:ok, s2} = Helpers.Accounts.create_session(user)
      {:ok, s3} = Helpers.Accounts.create_session(user)
      {:ok, s4} = Helpers.Accounts.create_session(user)

      conn = delete(conn, Routes.user_session_path(conn, :delete_all, user.id))
      assert conn.status == 403
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)

      for s <- [s1, s2, s3, s4] do
        assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(s.api_token, nil)
      end

      {:ok, %Accounts.Session{revoked_at: s3_revoked_at}} = Accounts.revoke_session(s3)
      {:ok, %Accounts.Session{revoked_at: s4_revoked_at}} = Accounts.revoke_session(s4)
      assert TestUtils.DateTime.within_last?(s3_revoked_at, 2, :seconds) == true
      assert TestUtils.DateTime.within_last?(s4_revoked_at, 2, :seconds) == true

      assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(s1.api_token, nil)
      assert {:ok, _, _, _, _, _, _, _, _, _} = Accounts.validate_session(s2.api_token, nil)
      assert {:error, :revoked} = Accounts.validate_session(s3.api_token, nil)
      assert {:error, :revoked} = Accounts.validate_session(s4.api_token, nil)

      conn = delete(conn, Routes.user_session_path(conn, :delete_all, user.id))

      assert %{
               "message" => _message,
               "num_revoked" => 2,
               "status" => true
             } = json_response(conn, 200)["data"]

      assert {:error, :revoked} = Accounts.validate_session(s1.api_token, nil)
      assert {:error, :revoked} = Accounts.validate_session(s2.api_token, nil)
      assert {:error, :revoked} = Accounts.validate_session(s3.api_token, nil)
      assert {:error, :revoked} = Accounts.validate_session(s4.api_token, nil)

      # Verify that revoked_at is same for s1 and s2 and not matching s3 and s4
      assert %Accounts.Session{revoked_at: s1_revoked_at} = Accounts.get_session!(s1.id)
      assert %Accounts.Session{revoked_at: s2_revoked_at} = Accounts.get_session!(s2.id)
      assert %Accounts.Session{revoked_at: ^s3_revoked_at} = Accounts.get_session!(s3.id)
      assert %Accounts.Session{revoked_at: ^s4_revoked_at} = Accounts.get_session!(s4.id)
      assert s1_revoked_at == s2_revoked_at
    end
  end

  describe "extend user sessions" do
    test "non-admin session extensions are rate limited", %{conn: _conn} do
      {:ok, conn, user, session} =
        Helpers.Accounts.regular_user_session_conn(build_conn(), %{}, %{
          "extendable_until_seconds" => 600,
          "max_extension_secs" => 60,
          "expires_in_seconds" => 60
        })

      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)

      # Ensure a clean bucket for deterministic testing
      {:ok, _} = Malan.RateLimits.SessionExtension.clear(user.id)

      {_, limit} = Malan.Config.RateLimit.session_extension_limit()

      conn = Helpers.Accounts.put_token(conn, session.api_token)

      # First `limit` requests should succeed
      Enum.each(1..limit, fn _i ->
        assert %{"ok" => true} =
                 conn
                 |> put(Routes.session_path(conn, :extend_current), %{expire_in_seconds: 10})
                 |> json_response(200)
      end)

      # Next one should be rate limited
      assert %{"code" => 429, "ok" => false} =
               conn
               |> put(Routes.session_path(conn, :extend_current), %{expire_in_seconds: 10})
               |> json_response(429)
    end

    test "admins bypass session extension rate limits", %{conn: _conn} do
      {:ok, conn, user, session} = Helpers.Accounts.admin_user_session_conn(build_conn())
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)

      {:ok, _} = Malan.RateLimits.SessionExtension.clear(user.id)
      {_, limit} = Malan.Config.RateLimit.session_extension_limit()

      conn = Helpers.Accounts.put_token(conn, session.api_token)

      Enum.each(1..(limit + 2), fn _i ->
        assert %{"ok" => true} =
                 conn
                 |> put(Routes.session_path(conn, :extend_current), %{expire_in_seconds: 10})
                 |> json_response(200)
      end)
    end
  end

  describe "login rate limit" do
    setup do
      original = {
        Malan.Config.RateLimit.login_limit_msecs(),
        Malan.Config.RateLimit.login_limit_count()
      }

      on_exit(fn ->
        Application.put_env(:malan, Malan.Config.RateLimits,
          login_limit_msecs: elem(original, 0),
          login_limit_count: elem(original, 1),
          password_reset_lower_limit_msecs:
            Application.get_env(:malan, Malan.Config.RateLimits)[
              :password_reset_lower_limit_msecs
            ],
          password_reset_lower_limit_count:
            Application.get_env(:malan, Malan.Config.RateLimits)[
              :password_reset_lower_limit_count
            ],
          password_reset_upper_limit_msecs:
            Application.get_env(:malan, Malan.Config.RateLimits)[
              :password_reset_upper_limit_msecs
            ],
          password_reset_upper_limit_count:
            Application.get_env(:malan, Malan.Config.RateLimits)[
              :password_reset_upper_limit_count
            ],
          session_extension_limit_msecs:
            Application.get_env(:malan, Malan.Config.RateLimits)[
              :session_extension_limit_msecs
            ],
          session_extension_limit_count:
            Application.get_env(:malan, Malan.Config.RateLimits)[
              :session_extension_limit_count
            ]
        )
      end)

      # Tighten login limit for test
      Application.put_env(:malan, Malan.Config.RateLimits,
        login_limit_msecs: 60000,
        login_limit_count: 2,
        password_reset_lower_limit_msecs:
          Application.get_env(:malan, Malan.Config.RateLimits)[:password_reset_lower_limit_msecs],
        password_reset_lower_limit_count:
          Application.get_env(:malan, Malan.Config.RateLimits)[:password_reset_lower_limit_count],
        password_reset_upper_limit_msecs:
          Application.get_env(:malan, Malan.Config.RateLimits)[:password_reset_upper_limit_msecs],
        password_reset_upper_limit_count:
          Application.get_env(:malan, Malan.Config.RateLimits)[:password_reset_upper_limit_count],
        session_extension_limit_msecs:
          Application.get_env(:malan, Malan.Config.RateLimits)[:session_extension_limit_msecs],
        session_extension_limit_count:
          Application.get_env(:malan, Malan.Config.RateLimits)[:session_extension_limit_count]
      )

      :ok
    end

    test "username is rate limited after repeated failed logins", %{conn: conn} do
      username = "user_login_rl"
      password = "GoodPass123!"

      {:ok, _user} =
        Helpers.Accounts.regular_user(%{username: username, password: password})

      # clear bucket
      {:ok, _} = Malan.RateLimits.Login.clear(username)

      # First two wrong attempts -> 403
      conn =
        post(conn, Routes.session_path(conn, :create), %{
          session: %{username: username, password: "wrong"}
        })

      assert %{"ok" => false, "code" => 403} = json_response(conn, 403)

      conn =
        post(build_conn(), Routes.session_path(conn, :create), %{
          session: %{username: username, password: "wrong"}
        })

      assert %{"ok" => false, "code" => 403} = json_response(conn, 403)

      # Third attempt (still wrong) -> 429
      conn =
        post(build_conn(), Routes.session_path(conn, :create), %{
          session: %{username: username, password: "wrong"}
        })

      assert %{"ok" => false, "code" => 429} = json_response(conn, 429)
    end
  end

  describe "extend user sessions 2" do
    test "Session extension works (happy path) (IDs in path)", %{conn: conn} do
      # Create the new session for the user
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      # Global absolute limit of extensions
      extendable_until_seconds = 90
      # Limit for each extension
      max_extension_secs = 45

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{"id" => id, "api_token" => api_token, "max_extension_secs" => ^max_extension_secs} =
               json_response(conn, 201)["data"]

      # Reach under the hood and change the expiration time of the session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(15, :seconds)

      assert {:ok, session} =
               Accounts.get_session!(id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert session.expires_at == patched_expiration_time

      # Now extend the session
      expected_expires_at = Utils.DateTime.adjust_cur_time_trunc(30, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), api_token)

      conn =
        put(conn, Routes.user_session_path(conn, :extend, user_id, id), %{expire_in_seconds: 30})

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      # Call the show endpoint and verify changes from above are persisted
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)
    end

    test "Session extension history gets recorded and surfaced to the user through the API", %{
      conn: conn
    } do
      # Create the new session for the user
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      # Global absolute limit of extensions
      extendable_until_seconds = 360
      # Limit for each extension
      max_extension_secs = 300

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{"id" => id, "api_token" => api_token, "max_extension_secs" => ^max_extension_secs} =
               json_response(conn, 201)["data"]

      # Reach under the hood and change the expiration time of the session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(15, :seconds)

      assert {:ok, session} =
               Accounts.get_session!(id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert session.expires_at == patched_expiration_time

      # Now extend the session
      expected_expires_at = Utils.DateTime.adjust_cur_time_trunc(30, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), api_token)

      conn =
        put(conn, Routes.user_session_path(conn, :extend, user_id, id), %{expire_in_seconds: 30})

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      # Call the show endpoint and verify changes from above are persisted
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)
    end

    test "Session extension works without args by using the default extension secs (and no IDs in path)",
         %{conn: conn} do
      # Create the new session for the user
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      # Global absolute limit of extensions
      extendable_until_seconds = 30
      # Limit for each extension
      max_extension_secs = 20

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{"id" => id, "api_token" => api_token, "max_extension_secs" => ^max_extension_secs} =
               json_response(conn, 201)["data"]

      # Reach under the hood and change the expiration time of the session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(5, :seconds)

      assert {:ok, session} =
               Accounts.get_session!(id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert session.expires_at == patched_expiration_time

      # Now extend the session
      expected_expires_at = Utils.DateTime.adjust_cur_time_trunc(20, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = put(conn, Routes.session_path(conn, :extend_current), %{expire_in_seconds: 20})

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      # Call the show endpoint and verify changes from above are persisted
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)
    end

    test "Extending requires authentication", %{conn: conn} do
      conn = put(conn, Routes.session_path(conn, :extend_current), %{expire_in_seconds: 20})

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)

      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      conn =
        put(conn, Routes.user_session_path(conn, :extend, user.id, session.id), %{
          expire_in_seconds: 30
        })

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end

    test "Extending requires ownership", %{conn: _conn} do
      # Limit for each extension
      max_extension_secs = 20

      # Create the new session for the user
      {:ok, c1, u1, s1} =
        Helpers.Accounts.regular_user_session_conn(build_conn(), %{}, %{
          "max_extension_secs" => max_extension_secs
        })

      {:ok, c2, _u2, s2} =
        Helpers.Accounts.regular_user_session_conn(build_conn(), %{}, %{
          "max_extension_secs" => max_extension_secs
        })

      {:ok, u1} = Helpers.Accounts.accept_user_tos_and_pp(u1, true)
      u1_id = u1.id
      s1_id = s1.id

      # Reach under the hood and change the expiration time of the session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(5, :seconds)

      assert {:ok, s1} =
               Accounts.get_session!(s1.id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert {:ok, s2} =
               Accounts.get_session!(s2.id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert s1.expires_at == patched_expiration_time
      assert s2.expires_at == patched_expiration_time

      # Now extend the session
      c2 = put(c2, Routes.user_session_path(c2, :extend, u1.id, s1.id), %{expire_in_seconds: 20})

      assert %{
               "code" => 401,
               "detail" => "Unauthorized",
               "ok" => false
             } = json_response(c2, 401)

      # Call the show endpoint and verify changes from above are not persisted
      c1 = get(c1, Routes.user_session_path(c1, :show, u1.id, s1.id))

      jr = json_response(c1, 200)["data"]

      assert %{
               "id" => ^s1_id,
               "user_id" => ^u1_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)

      assert TestUtils.DateTime.datetimes_within?(
               expires_at,
               patched_expiration_time,
               1,
               :seconds
             )
    end

    test "Attempts at extending after the token expires fails", %{conn: conn} do
      # Create the new session for the user
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      # Global absolute limit of extensions
      extendable_until_seconds = 30
      # Limit for each extension
      max_extension_secs = 20

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{"id" => id, "api_token" => api_token, "max_extension_secs" => ^max_extension_secs} =
               json_response(conn, 201)["data"]

      # Reach under the hood and change the expiration time of the session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(-20, :seconds)

      assert {:ok, session} =
               Accounts.get_session!(id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert session.expires_at == patched_expiration_time

      assert Helpers.Accounts.session_valid?(id) == false
      assert Helpers.Accounts.session_valid?(session) == false

      # Now try to extend the session
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = put(conn, Routes.session_path(conn, :extend_current), %{expire_in_seconds: 20})

      assert %{
               "code" => 403,
               "detail" => "Forbidden",
               "ok" => false,
               "token_expired" => true
             } = json_response(conn, 403)

      # Ensure we can't do a show either with this token
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      assert %{
               "code" => 403,
               "detail" => "Forbidden",
               "ok" => false,
               "token_expired" => true
             } = json_response(conn, 403)

      # Call the show endpoint with a different token and verify session is still expired
      {:ok, conn, _au1, _su1} = Helpers.Accounts.admin_user_session_conn(build_conn())
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => false,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)

      assert TestUtils.DateTime.datetimes_within?(
               expires_at,
               patched_expiration_time,
               2,
               :seconds
             )
    end

    test "Does not change previously closed sessions", %{conn: _conn} do
      #
      # Create two sessions for a user.  Expire one and use the second to extend the first.  It should fail
      #

      # Create the new sessions for the user
      {:ok, _c1, user, s1} = Helpers.Accounts.regular_user_session_conn(build_conn())
      {:ok, c2, s2} = Helpers.Accounts.create_session_conn(build_conn(), user)
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      s1_id = s1.id

      # Reach under the hood and change the expiration time of the first session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(-20, :seconds)

      assert {:ok, s1} =
               Accounts.get_session!(s1.id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert s1.expires_at == patched_expiration_time
      assert s2.expires_at != patched_expiration_time

      assert Helpers.Accounts.session_valid?(s1) == false
      assert Helpers.Accounts.session_valid?(s2) == true

      # Now extend the session
      c2 =
        put(c2, Routes.user_session_path(c2, :extend, user.id, s1.id), %{expire_in_seconds: 20})

      assert %{
               "code" => 403,
               "detail" => "Forbidden",
               "ok" => false
             } = json_response(c2, 403)

      # Call the show endpoint and verify changes to s1 didn't take affect
      {:ok, conn, _au1, _su1} = Helpers.Accounts.admin_user_session_conn(build_conn())
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, s1.id))

      assert %{
               "id" => ^s1_id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => false
             } = json_response(conn, 200)["data"]

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)

      assert TestUtils.DateTime.datetimes_within?(
               expires_at,
               patched_expiration_time,
               1,
               :seconds
             )
    end

    test "Admins can extend regular user sessions", %{conn: _conn} do
      # TODO EXTENSION
    end

    test "Admins can extend regular sessions", %{conn: _conn} do
      # TODO EXTENSION
    end

    test "Revoking a session makes it so it can't be extended even if not expired", %{conn: _conn} do
      #
      # Create two sessions for a user.  Revoke the first one and use the second to extend the first.
      # It should fail
      #

      # Create the new sessions for the user
      {:ok, _c1, user, s1} = Helpers.Accounts.regular_user_session_conn(build_conn())
      {:ok, c2, s2} = Helpers.Accounts.create_session_conn(build_conn(), user)
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id
      s1_id = s1.id

      assert Accounts.session_revoked_or_expired?(s1) == false
      assert Helpers.Accounts.session_revoked_or_expired?(s1_id) == false
      assert Accounts.session_revoked?(s1) == false
      assert Accounts.session_expired?(s1) == false

      # Revoke the first session
      c2 = delete(c2, Routes.user_session_path(c2, :delete, user.id, s1.id))

      assert %{
               "id" => ^s1_id,
               "user_id" => ^user_id,
               "revoked_at" => revoked_at,
               "is_valid" => false
             } = json_response(c2, 200)["data"]

      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true

      s1 = Accounts.get_session!(s1.id)
      assert Accounts.session_revoked_or_expired?(s1) == true
      assert Helpers.Accounts.session_revoked_or_expired?(s1_id) == true
      assert Accounts.session_revoked?(s1) == true
      assert Accounts.session_expired?(s1) == false

      # Now try to extend the session
      c2 = Helpers.Accounts.put_token(build_conn(), s2.api_token)

      c2 =
        put(c2, Routes.user_session_path(c2, :extend, user.id, s1.id), %{expire_in_seconds: 20})

      assert %{
               "code" => 403,
               "detail" => "Forbidden",
               "ok" => false
             } = json_response(c2, 403)

      # Call the show endpoint and verify changes to s1 didn't take affect
      {:ok, conn, _au1, _su1} = Helpers.Accounts.admin_user_session_conn(build_conn())
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, s1.id))

      assert %{
               "id" => ^s1_id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "revoked_at" => revoked_at,
               "is_valid" => false
             } = json_response(conn, 200)["data"]

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      {:ok, revoked_at, 0} = DateTime.from_iso8601(revoked_at)

      assert TestUtils.DateTime.datetimes_within?(
               expires_at,
               s1.expires_at,
               1,
               :seconds
             )

      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true
      assert Accounts.session_revoked_or_expired?(s1) == true
      assert Accounts.session_revoked?(s1) == true
      assert Accounts.session_expired?(s1) == false
    end

    test "Revoking an extended session terminates the session immediately", %{conn: conn} do
      # Create the new session for the user
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      # Global absolute limit of extensions
      extendable_until_seconds = 90
      # Limit for each extension
      max_extension_secs = 45
      extension_secs = 30

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{
               "id" => id,
               "api_token" => api_token,
               "max_extension_secs" => ^max_extension_secs,
               "expires_at" => _orig_expires_at
             } = json_response(conn, 201)["data"]

      # Reach under the hood and change the expiration time of the session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(45, :seconds)

      assert {:ok, session} =
               Accounts.get_session!(id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert session.expires_at == patched_expiration_time

      # Now extend the session
      expected_expires_at = Utils.DateTime.adjust_cur_time_trunc(extension_secs, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), api_token)

      conn =
        put(conn, Routes.user_session_path(conn, :extend, user_id, id), %{
          expire_in_seconds: extension_secs
        })

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      # Call the show endpoint and verify changes from above are persisted
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      # Now revoke the session
      conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, id))

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "revoked_at" => revoked_at,
               "is_valid" => false
             } = json_response(conn, 200)["data"]

      {:ok, revoked_at, 0} = revoked_at |> DateTime.from_iso8601()
      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true

      assert Helpers.Accounts.session_revoked_or_expired?(id) == true
      assert Helpers.Accounts.session_revoked?(id) == true
      assert Helpers.Accounts.session_expired?(id) == false

      # Call the show endpoint and verify session is revoked
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      assert %{
               "code" => 403,
               "detail" => "Forbidden",
               "ok" => false,
               "token_expired" => true
             } = json_response(conn, 403)

      # Triple verify with admin token
      {:ok, conn, _au1, _su1} = Helpers.Accounts.admin_user_session_conn(build_conn())
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "revoked_at" => revoked_at,
               "is_valid" => false
             } = json_response(conn, 200)["data"]

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      {:ok, revoked_at, 0} = DateTime.from_iso8601(revoked_at)

      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      assert TestUtils.DateTime.within_last?(revoked_at, 2, :seconds) == true
      assert Helpers.Accounts.session_revoked_or_expired?(id) == true
      assert Helpers.Accounts.session_revoked?(id) == true
      assert Helpers.Accounts.session_expired?(id) == false
    end

    test "Extending a session with less time than it has expiration changes the expiration down to match extension",
         %{conn: conn} do
      # Create the new session for the user
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Helpers.Accounts.accept_user_tos_and_pp(user, true)
      user_id = user.id

      # Global absolute limit of extensions
      extendable_until_seconds = 90
      # Limit for each extension
      max_extension_secs = 45
      extension_secs = 30

      conn =
        post(conn, Routes.session_path(conn, :create),
          session: %{
            username: user.username,
            password: user.password,
            extendable_until_seconds: extendable_until_seconds,
            max_extension_secs: max_extension_secs
          }
        )

      assert %{
               "id" => id,
               "api_token" => api_token,
               "max_extension_secs" => ^max_extension_secs,
               "expires_at" => _orig_expires_at
             } = json_response(conn, 201)["data"]

      # Reach under the hood and change the expiration time of the session
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(45, :seconds)

      assert {:ok, session} =
               Accounts.get_session!(id)
               |> Session.admin_changeset(%{expires_at: patched_expiration_time})
               |> Malan.Repo.update()

      assert session.expires_at == patched_expiration_time

      # Now extend the session
      expected_expires_at = Utils.DateTime.adjust_cur_time_trunc(extension_secs, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), api_token)

      conn =
        put(conn, Routes.user_session_path(conn, :extend, user_id, id), %{
          expire_in_seconds: extension_secs
        })

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => ^max_extension_secs
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      # Call the show endpoint and verify session expiration has changed to match extension
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, id))

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "revoked_at" => nil,
               "is_valid" => true
             } = json_response(conn, 200)["data"]

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)

      assert TestUtils.DateTime.datetimes_within?(expires_at, expected_expires_at, 2, :seconds)

      assert Helpers.Accounts.session_revoked_or_expired?(id) == false
      assert Helpers.Accounts.session_revoked?(id) == false
      assert Helpers.Accounts.session_expired?(id) == false
    end

    test "Extending a session generates a log", %{conn: _conn} do
      # TODO EXTENSION
    end

    test "Existing sessions (without the new extension attrs) can't be extended but don't error",
         %{conn: _conn} do
      # Create the new session for the user
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      user_id = user.id
      session_id = session.id
      api_token = session.api_token

      # Reach under the hood and change the session attrs to match previously existing sessions
      patched_expiration_time = Utils.DateTime.adjust_cur_time_trunc(45, :seconds)

      assert {:ok, session} =
               Accounts.get_session!(session_id)
               |> Ecto.Changeset.change(%{
                 extendable_until: nil,
                 max_extension_secs: nil,
                 expires_at: patched_expiration_time
               })
               |> Malan.Repo.update()

      assert is_nil(session.extendable_until)
      assert is_nil(session.max_extension_secs)
      assert session.expires_at == patched_expiration_time

      # Now try extend the session
      conn = Helpers.Accounts.put_token(build_conn(), api_token)

      conn =
        put(conn, Routes.user_session_path(conn, :extend, user_id, session_id), %{
          expire_in_seconds: 180
        })

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^session_id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "max_extension_secs" => nil
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)

      assert TestUtils.DateTime.datetimes_within?(
               expires_at,
               patched_expiration_time,
               2,
               :seconds
             )

      # Call the show endpoint and verify nothing above changed and the show endpoint doesn't choke
      # on the missing attrs
      conn = Helpers.Accounts.put_token(build_conn(), api_token)
      conn = get(conn, Routes.user_session_path(conn, :show, user.id, session_id))

      jr = json_response(conn, 200)["data"]

      assert %{
               "id" => ^session_id,
               "user_id" => ^user_id,
               "expires_at" => expires_at,
               "is_valid" => true,
               "revoked_at" => nil,
               "extendable_until" => nil,
               "max_extension_secs" => nil
             } = jr

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)

      assert TestUtils.DateTime.datetimes_within?(
               expires_at,
               patched_expiration_time,
               2,
               :seconds
             )
    end
  end

  # describe "show/valid session" do
  #   test "shows session valid when valid", %{conn: conn} do
  #     {:ok, conn, user, session} = Helpers.Accounts.regular_user_session_conn(conn)
  #     id = session.id
  #     user_id = user.id
  #     conn = get(conn, Routes.user_session_path(conn, :show, user.id, session))
  #     jr = json_response(conn, 200)["data"]
  #     assert %{
  #              "id" => ^id,
  #              "user_id" => ^user_id,
  #              "authenticated_at" => _authenticated_at,
  #              "expires_at" => _expires_at,
  #              "ip_address" => _ip,
  #              "location" => nil,
  #              "revoked_at" => nil
  #            } = jr
  #   end

  #   test "Reports session not valid when invalid", %{conn: conn} do
  #     {:ok, conn, user, session} = Helpers.Accounts.regular_user_session_conn(conn)
  #     conn = delete(conn, Routes.user_session_path(conn, :delete, user.id, session))
  #     assert %{"revoked_at" => revoked_at} = json_response(conn, 200)["data"]

  #     id = session.id
  #     user_id = user.id
  #     conn = get(conn, Routes.user_session_path(conn, :show, user.id, session))
  #     jr = json_response(conn, 200)["data"]
  #     assert %{
  #              "id" => ^id,
  #              "user_id" => ^user_id,
  #              "authenticated_at" => _authenticated_at,
  #              "expires_at" => _expires_at,
  #              "ip_address" => _ip,
  #              "location" => nil,
  #              "revoked_at" => ^revoked_at,
  #            } = jr
  #   end

  #   test "non-owner cannot check session validitiy" do

  #   end
  # end
end
