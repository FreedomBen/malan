defmodule MalanWeb.SessionExtensionControllerTest do
  use MalanWeb.ConnCase

  alias Malan.Utils
  alias Malan.Accounts

  alias Malan.Test.Helpers

  alias Malan.Test.Utils, as: TestUtils

  @default_page_num 0
  @default_page_size 10

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "show and index session_extensions" do
    test "lists and shows all session_extensions", %{conn: conn} do
      {:ok, conn, user, s1} =
        Helpers.Accounts.regular_user_session_conn(conn, %{}, %{
          "max_extension_secs" => 120,
          "expires_in_seconds" => 30,
          "extendable_until" => 360
        })

      user_id = user.id
      s1_id = s1.id

      conn = get(conn, Routes.session_extension_path(conn, :index, s1.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => @default_page_num,
               "page_size" => @default_page_size,
               "data" => []
             } = json_response(conn, 200)

      # Make a first extension
      {:ok, {s2, se2}} =
        Accounts.extend_session(s1, %{"expire_in_seconds" => 30}, %{
          authed_user_id: s1.user_id,
          authed_session_id: s1.id
        })

      s2_expected_new_expires_at = Utils.DateTime.adjust_cur_time_trunc(30, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.session_extension_path(conn, :index, s1.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => @default_page_num,
               "page_size" => @default_page_size,
               "data" => [
                 %{
                   "id" => se2_id,
                   "user_id" => ^user_id,
                   "session_id" => ^s1_id,
                   "old_expires_at" => s2_old_expires_at,
                   "new_expires_at" => s2_new_expires_at,
                   "extended_by_seconds" => 30,
                   "extended_by_user" => ^user_id,
                   "extended_by_session" => ^s1_id
                 }
               ]
             } = json_response(conn, 200)

      {:ok, s2_old_expires_at_dt, 0} = DateTime.from_iso8601(s2_old_expires_at)
      {:ok, s2_new_expires_at_dt, 0} = DateTime.from_iso8601(s2_new_expires_at)

      assert s2_old_expires_at_dt == s1.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               s2_new_expires_at_dt,
               s2_expected_new_expires_at,
               2,
               :seconds
             )

      # Check the show endpoint
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.session_extension_path(conn, :show, se2.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "data" => %{
                 "id" => ^se2_id,
                 "user_id" => ^user_id,
                 "session_id" => ^s1_id,
                 "old_expires_at" => ^s2_old_expires_at,
                 "new_expires_at" => ^s2_new_expires_at,
                 "extended_by_seconds" => 30,
                 "extended_by_user" => ^user_id,
                 "extended_by_session" => ^s1_id
               }
             } = json_response(conn, 200)

      # Make second extension
      {:ok, {s3, se3}} =
        Accounts.extend_session(s2, %{"expire_in_seconds" => 60}, %{
          authed_user_id: s2.user_id,
          authed_session_id: s2.id
        })

      s3_expected_new_expires_at = Utils.DateTime.adjust_cur_time_trunc(60, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.session_extension_path(conn, :index, s1.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => @default_page_num,
               "page_size" => @default_page_size,
               "data" => [
                 %{
                   "id" => se3_id,
                   "user_id" => ^user_id,
                   "session_id" => ^s1_id,
                   "old_expires_at" => s3_old_expires_at,
                   "new_expires_at" => s3_new_expires_at,
                   "extended_by_seconds" => 60,
                   "extended_by_user" => ^user_id,
                   "extended_by_session" => ^s1_id
                 },
                 %{
                   "id" => ^se2_id,
                   "user_id" => ^user_id,
                   "session_id" => ^s1_id,
                   "old_expires_at" => ^s2_old_expires_at,
                   "new_expires_at" => ^s2_new_expires_at,
                   "extended_by_seconds" => 30,
                   "extended_by_user" => ^user_id,
                   "extended_by_session" => ^s1_id
                 }
               ]
             } = json_response(conn, 200)

      {:ok, s3_old_expires_at_dt, 0} = DateTime.from_iso8601(s3_old_expires_at)
      {:ok, s3_new_expires_at_dt, 0} = DateTime.from_iso8601(s3_new_expires_at)

      assert s3_old_expires_at_dt == s2.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               s3_new_expires_at_dt,
               s3_expected_new_expires_at,
               2,
               :seconds
             )

      # Check the show endpoint
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.session_extension_path(conn, :show, se3.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "data" => %{
                 "id" => ^se3_id,
                 "user_id" => ^user_id,
                 "session_id" => ^s1_id,
                 "old_expires_at" => ^s3_old_expires_at,
                 "new_expires_at" => ^s3_new_expires_at,
                 "extended_by_seconds" => 60,
                 "extended_by_user" => ^user_id,
                 "extended_by_session" => ^s1_id
               }
             } = json_response(conn, 200)

      # Make third extension
      {:ok, {_s4, se4}} =
        Accounts.extend_session(s3, %{"expire_in_seconds" => 90}, %{
          authed_user_id: s1.user_id,
          authed_session_id: s1.id
        })

      s4_expected_new_expires_at = Utils.DateTime.adjust_cur_time_trunc(90, :seconds)

      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.session_extension_path(conn, :index, s1.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "page_num" => @default_page_num,
               "page_size" => @default_page_size,
               "data" => [
                 %{
                   "id" => se4_id,
                   "user_id" => ^user_id,
                   "session_id" => ^s1_id,
                   "old_expires_at" => s4_old_expires_at,
                   "new_expires_at" => s4_new_expires_at,
                   "extended_by_seconds" => 90,
                   "extended_by_user" => ^user_id,
                   "extended_by_session" => ^s1_id
                 },
                 %{
                   "id" => ^se3_id,
                   "user_id" => ^user_id,
                   "session_id" => ^s1_id,
                   "old_expires_at" => ^s3_old_expires_at,
                   "new_expires_at" => ^s3_new_expires_at,
                   "extended_by_seconds" => 60,
                   "extended_by_user" => ^user_id,
                   "extended_by_session" => ^s1_id
                 },
                 %{
                   "id" => ^se2_id,
                   "user_id" => ^user_id,
                   "session_id" => ^s1_id,
                   "old_expires_at" => ^s2_old_expires_at,
                   "new_expires_at" => ^s2_new_expires_at,
                   "extended_by_seconds" => 30,
                   "extended_by_user" => ^user_id,
                   "extended_by_session" => ^s1_id
                 }
               ]
             } = json_response(conn, 200)

      {:ok, s4_old_expires_at_dt, 0} = DateTime.from_iso8601(s4_old_expires_at)
      {:ok, s4_new_expires_at_dt, 0} = DateTime.from_iso8601(s4_new_expires_at)

      assert s4_old_expires_at_dt == s3.expires_at

      assert TestUtils.DateTime.datetimes_within?(
               s4_new_expires_at_dt,
               s4_expected_new_expires_at,
               2,
               :seconds
             )

      # Check the show endpoint
      conn = Helpers.Accounts.put_token(build_conn(), s1.api_token)
      conn = get(conn, Routes.session_extension_path(conn, :show, se4.id))

      assert %{
               "ok" => true,
               "code" => 200,
               "data" => %{
                 "id" => ^se4_id,
                 "user_id" => ^user_id,
                 "session_id" => ^s1_id,
                 "old_expires_at" => ^s4_old_expires_at,
                 "new_expires_at" => ^s4_new_expires_at,
                 "extended_by_seconds" => 90,
                 "extended_by_user" => ^user_id,
                 "extended_by_session" => ^s1_id
               }
             } = json_response(conn, 200)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.session_extension_path(conn, :index, "some-id"))

      assert %{
               "ok" => false,
               "code" => 403,
               "detail" => "Forbidden",
               "message" => _
             } = json_response(conn, 403)
    end
  end
end
