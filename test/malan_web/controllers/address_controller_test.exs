defmodule MalanWeb.AddressControllerTest do
  use MalanWeb.ConnCase

  #import Malan.AccountsFixtures

  alias Malan.Accounts.Address

  alias Malan.Test.Helpers

  @create_attrs %{
    "city" => "some city",
    "country" => "some country",
    "line_1" => "some line_1",
    "line_2" => "some line_2",
    "name" => "some name",
    "postal" => "some postal",
    "primary" => true,
    "state" => "some state",
    "verified_at" => ~U[2021-12-19 01:54:00Z]
  }
  @update_attrs %{
    "city" => "some updated city",
    "country" => "some updated country",
    "line_1" => "some updated line_1",
    "line_2" => "some updated line_2",
    "name" => "some updated name",
    "postal" => "some updated postal",
    "primary" => false,
    "state" => "some updated state",
    "verified_at" => ~U[2021-12-20 01:54:00Z]
  }
  @invalid_attrs %{city: nil, country: nil, line_1: nil, line_2: nil, name: nil, postal: nil, primary: nil, state: nil, verified_at: nil}

  def fixture(:address) do
    {:ok, address} = Malan.Accounts.create_address(@create_attrs)
    address
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all addresses", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.address_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.address_path(conn, :index))
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.address_path(conn, :index))
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = get(conn, Routes.address_path(conn, :index))
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "show" do
    test "gets address", %{conn: conn} do
      address = fixture(:address)
      id = address.id
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.address_path(conn, :show, id))
      assert %{
               "id" => ^id,
               "city" => "some city",
               "country" => "some country",
               "line_1" => "some line_1",
               "line_2" => "some line_2",
               "name" => "some name",
               "postal" => "some postal",
               "primary" => true,
               "state" => "some state",
               "verified_at" => "2021-12-19T01:54:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.address_path(conn, :show, "42"))
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.address_path(conn, :show, user.id))
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = get(conn, Routes.address_path(conn, :show, user.id))
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "create address" do
    test "renders address when data is valid", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.address_path(conn, :create), address: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.address_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "city" => "some city",
               "country" => "some country",
               "line_1" => "some line_1",
               "line_2" => "some line_2",
               "name" => "some name",
               "postal" => "some postal",
               "primary" => true,
               "state" => "some state",
               "verified_at" => "2021-12-19T01:54:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.address_path(conn, :create), address: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    # If regular users should be allowed to create a address, then remove this test
    test "won't work for regular user", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.address_path(conn, :create), address: @create_attrs)
      assert conn.status == 401
    end

    test "requires being authenticated", %{conn: conn} do
      conn = post(conn, Routes.address_path(conn, :create), address: @create_attrs)
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = post(conn, Routes.address_path(conn, :create), address: @create_attrs)
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = post(conn, Routes.address_path(conn, :create), address: @create_attrs)
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "update address" do
    setup [:create_address]

    test "renders address when data is valid", %{conn: conn, address: %Address{id: id} = address} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.address_path(conn, :update, address), address: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.address_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "city" => "some updated city",
               "country" => "some updated country",
               "line_1" => "some updated line_1",
               "line_2" => "some updated line_2",
               "name" => "some updated name",
               "postal" => "some updated postal",
               "primary" => false,
               "state" => "some updated state",
               "verified_at" => "2021-12-20T01:54:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, address: address} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.address_path(conn, :update, address), address: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    # If regular users should be allowed to create a address, then remove this test
    test "won't work for regular user", %{conn: conn, address: address} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.address_path(conn, :update, address), address: @update_attrs)
      assert conn.status == 401
    end

    test "requires being authenticated", %{conn: conn, address: _address} do
      conn = put(conn, Routes.address_path(conn, :update, "42"), address: @update_attrs)
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn, address: address} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.address_path(conn, :update, address), address: @update_attrs)
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = put(conn, Routes.address_path(conn, :update, address), address: @update_attrs)
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "delete address" do
    setup [:create_address]

    test "deletes chosen address", %{conn: conn, address: address} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.address_path(conn, :delete, address))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.address_path(conn, :show, address))
      end
    end

    test "Requires being authenticated", %{conn: conn, address: address} do
      conn = delete(conn, Routes.address_path(conn, :delete, address))
      assert conn.status == 403
    end

    # If regular users should be allowed to create a address, then remove this test
    test "won't work for regular user", %{conn: conn, address: address} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.address_path(conn, :delete, address))
      assert conn.status == 401
    end

    test "requires accepting ToS and PP", %{conn: conn, address: address} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.address_path(conn, :delete, address))
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = delete(conn, Routes.address_path(conn, :delete, address))
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  defp create_address(_) do
    address = fixture(:address)
    %{address: address}
  end
end
