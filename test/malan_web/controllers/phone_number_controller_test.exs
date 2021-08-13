defmodule MalanWeb.PhoneNumberControllerTest do
  use MalanWeb.ConnCase

  #import Malan.AccountsFixtures

  alias Malan.Accounts.PhoneNumber

  alias Malan.Test.Helpers

  @create_attrs %{
    "number" => "some number",
    "primary" => true,
    "verified" => "2010-04-17T14:00:00Z"
  }
  @update_attrs %{
    "number" => "some updated number",
    "primary" => false,
    "verified" => "2011-05-18T15:01:01Z"
  }
  @invalid_attrs %{number: nil, primary: nil, verified: nil}

  def fixture(:phone_number) do
    {:ok, phone_number} = Malan.Accounts.create_phone_number(@create_attrs)
    phone_number
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all phone_numbers", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.user_phone_number_path(conn, :index, user.id))
      assert json_response(conn, 200)["data"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.user_phone_number_path(conn, :index, "abcd"))
      assert conn.status == 403
    end

    #test "requires accepting ToS and PP", %{conn: conn} do
    #  {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #  conn = Helpers.Accounts.put_token(conn, session.api_token)
    #  conn = get(conn, Routes.user_phone_number_path(conn, :index, user.id))
    #  # We haven't accepted the terms of service yet so expect 461
    #  assert conn.status == 461

    #  {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #  conn = get(conn, Routes.user_phone_number_path(conn, :index, user.id))
    #  # We haven't accepted the PP yet so expect 462
    #  assert conn.status == 462
    #end
  end

  describe "show" do
    test "gets phone_number", %{conn: conn} do
      phone_number = fixture(:phone_number)
      id = phone_number.id
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.user_phone_number_path(conn, :show, user.id, id))
      assert %{
               "id" => ^id,
               "number" => "some number",
               "primary" => true,
               "verified" => "2010-04-17T14:00:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.user_phone_number_path(conn, :show, "43", "42"))
      assert conn.status == 403
    end

    #test "requires accepting ToS and PP", %{conn: conn} do
    #  {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #  conn = Helpers.Accounts.put_token(conn, session.api_token)
    #  conn = get(conn, Routes.user_phone_number_path(conn, :show, user.id))
    #  # We haven't accepted the terms of service yet so expect 461
    #  assert conn.status == 461

    #  {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #  conn = get(conn, Routes.user_phone_number_path(conn, :show, user.id))
    #  # We haven't accepted the PP yet so expect 462
    #  assert conn.status == 462
    #end
  end

  describe "create phone_number" do
    test "renders phone_number when data is valid", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.user_phone_number_path(conn, :create, user.id), phone_number: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.user_phone_number_path(conn, :show, user.id, id))

      assert %{
               "id" => ^id,
               "number" => "some number",
               "primary" => true,
               "verified" => "2010-04-17T14:00:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.user_phone_number_path(conn, :create, user.id), phone_number: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "requires being authenticated", %{conn: conn} do
      conn = post(conn, Routes.user_phone_number_path(conn, :create, "42"), phone_number: @create_attrs)
      assert conn.status == 403
    end

    #test "requires accepting ToS and PP", %{conn: conn} do
    #  {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #  conn = Helpers.Accounts.put_token(conn, session.api_token)
    #  conn = post(conn, Routes.user_phone_number_path(conn, :create, user.id), phone_number: @create_attrs)
    #  # We haven't accepted the terms of service yet so expect 461
    #  assert conn.status == 461

    #  {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #  conn = post(conn, Routes.user_phone_number_path(conn, :create, user.id), phone_number: @create_attrs)
    #  # We haven't accepted the PP yet so expect 462
    #  assert conn.status == 462
    #end
  end

  describe "update phone_number" do
    setup [:create_phone_number]

    test "renders phone_number when data is valid", %{conn: conn, phone_number: %PhoneNumber{id: id} = phone_number} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.user_phone_number_path(conn, :update, user.id, phone_number), phone_number: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_phone_number_path(conn, :show, user.id, id))

      assert %{
               "id" => ^id,
               "number" => "some updated number",
               "primary" => false,
               "verified" => "2011-05-18T15:01:01Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, phone_number: phone_number} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.user_phone_number_path(conn, :update, user.id, phone_number), phone_number: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "requires being authenticated", %{conn: conn, phone_number: _phone_number} do
      conn = put(conn, Routes.user_phone_number_path(conn, :update, "43", "42"), phone_number: @update_attrs)
      assert conn.status == 403
    end

    #test "requires accepting ToS and PP", %{conn: conn, phone_number: phone_number} do
    #  {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #  conn = Helpers.Accounts.put_token(conn, session.api_token)
    #  conn = put(conn, Routes.user_phone_number_path(conn, :update, user.id, phone_number), phone_number: @update_attrs)
    #  # We haven't accepted the terms of service yet so expect 461
    #  assert conn.status == 461

    #  {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #  conn = put(conn, Routes.user_phone_number_path(conn, :update, user.id, phone_number), phone_number: @update_attrs)
    #  # We haven't accepted the PP yet so expect 462
    #  assert conn.status == 462
    #end
  end

  describe "delete phone_number" do
    setup [:create_phone_number]

    test "deletes chosen phone_number", %{conn: conn, phone_number: phone_number} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.user_phone_number_path(conn, :delete, user.id, phone_number))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.user_phone_number_path(conn, :show, user.id, phone_number))
      end
    end

    test "Requires being authenticated", %{conn: conn, phone_number: phone_number} do
      conn = delete(conn, Routes.user_phone_number_path(conn, :delete, "42", phone_number))
      assert conn.status == 403
    end

    #test "requires accepting ToS and PP", %{conn: conn, phone_number: phone_number} do
    #  {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #  conn = Helpers.Accounts.put_token(conn, session.api_token)
    #  conn = delete(conn, Routes.user_phone_number_path(conn, :delete, user.id, phone_number))
    #  # We haven't accepted the terms of service yet so expect 461
    #  assert conn.status == 461

    #  {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #  conn = delete(conn, Routes.user_phone_number_path(conn, :delete, user.id, phone_number))
    #  # We haven't accepted the PP yet so expect 462
    #  assert conn.status == 462
    #end
  end

  defp create_phone_number(_) do
    phone_number = fixture(:phone_number)
    %{phone_number: phone_number}
  end
end
