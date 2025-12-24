defmodule MalanWeb.AddressControllerTest do
  use MalanWeb.ConnCase, async: true

  # import Malan.AccountsFixtures

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
  @invalid_attrs %{
    city: nil,
    country: nil,
    line_1: nil,
    line_2: nil,
    name: nil,
    postal: nil,
    primary: nil,
    state: nil,
    verified_at: nil
  }

  def fixture(:address, user_id) do
    {:ok, address} = Malan.Accounts.create_address(user_id, @create_attrs)
    address
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all addresses", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.user_address_path(conn, :index, user.id))
      assert json_response(conn, 200)["data"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.user_address_path(conn, :index, "42"))
      assert conn.status == 403
    end

    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = get(conn, Routes.user_address_path(conn, :index, user.id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.user_address_path(conn, :index, user.id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "show" do
    test "gets address", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      address = fixture(:address, user.id)
      id = address.id
      user_id = user.id
      conn = get(conn, Routes.user_address_path(conn, :show, user.id, id))

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "city" => "some city",
               "country" => "some country",
               "line_1" => "some line_1",
               "line_2" => "some line_2",
               "name" => "some name",
               "postal" => "some postal",
               "primary" => true,
               "state" => "some state",
               "verified_at" => nil
             } = json_response(conn, 200)["data"]
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.user_address_path(conn, :show, "43", "42"))
      assert conn.status == 403
    end

    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   address = fixture(:address, user.id)
    #   id = address.id
    #   user_id = user.id
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)

    #   conn = get(conn, Routes.user_address_path(conn, :show, user.id, id))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = get(conn, Routes.user_address_path(conn, :show, user.id, id))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "authorization bypass with mismatched user_id" do
    test "index does not leak other users' addresses", %{conn: conn} do
      {:ok, victim, _victim_session} = Helpers.Accounts.regular_user_with_session()
      victim_address = fixture(:address, victim.id)

      {:ok, conn, attacker, _attacker_session} = Helpers.Accounts.regular_user_session_conn(conn)

      conn = get(conn, Routes.user_address_path(conn, :index, attacker.id))
      data = json_response(conn, 200)["data"]

      refute Enum.any?(data, fn addr -> addr["id"] == victim_address.id end),
             "index should not return another user's address"
    end

    test "show rejects when id belongs to another user even if path user_id matches attacker",
         %{conn: conn} do
      {:ok, victim, _victim_session} = Helpers.Accounts.regular_user_with_session()
      victim_address = fixture(:address, victim.id)

      {:ok, conn, attacker, _attacker_session} = Helpers.Accounts.regular_user_session_conn(conn)

      conn = get(conn, Routes.user_address_path(conn, :show, attacker.id, victim_address.id))
      assert conn.status in [401, 403]
    end
  end

  describe "create address" do
    test "renders address when data is valid", %{conn: conn} do
      temp = @create_attrs
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      user_id = user.id

      # conn = post(conn, Routes.user_address_path(conn, :create, user_id), address: @create_attrs)
      conn = post(conn, Routes.user_address_path(conn, :create, user_id), address: temp)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.user_address_path(conn, :show, user_id, id))

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "city" => "some city",
               "country" => "some country",
               "line_1" => "some line_1",
               "line_2" => "some line_2",
               "name" => "some name",
               "postal" => "some postal",
               "primary" => true,
               "state" => "some state",
               "verified_at" => nil
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.user_address_path(conn, :create, user.id), address: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    # If regular users should be allowed to create a address, then remove this test
    # test "won't work for regular user", %{conn: conn} do
    #   {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
    #   conn = post(conn, Routes.user_address_path(conn, :create, user.id), address: @create_attrs)
    #   assert conn.status == 401
    # end

    test "requires being authenticated", %{conn: conn} do
      conn = post(conn, Routes.user_address_path(conn, :create, "42"), address: @create_attrs)
      assert conn.status == 403
    end

    # test "requires accepting ToS and PP", %{conn: conn} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = post(conn, Routes.user_address_path(conn, :create, user.id), address: @create_attrs)
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = post(conn, Routes.user_address_path(conn, :create, user.id), address: @create_attrs)
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "update address" do
    setup [:create_address]

    test "renders address when data is valid", %{
      conn: conn,
      user: user,
      session: session,
      address: %Address{id: id} = address
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)

      conn =
        put(conn, Routes.user_address_path(conn, :update, user.id, address),
          address: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_address_path(conn, :show, user.id, id))

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
               "verified_at" => nil
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      user: user,
      session: session,
      address: address
    } do
      conn = Helpers.Accounts.put_token(conn, session.api_token)

      conn =
        put(conn, Routes.user_address_path(conn, :update, user.id, address),
          address: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    # If regular users should be allowed to create a address, then remove this test
    # test "won't work for regular user", %{conn: conn, address: address} do
    #   {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
    #   conn = put(conn, Routes.user_address_path(conn, :update, user.id, address), address: @update_attrs)
    #   assert conn.status == 401
    # end

    test "requires being authenticated", %{conn: conn, address: _address} do
      conn =
        put(conn, Routes.user_address_path(conn, :update, "43", "42"), address: @update_attrs)

      assert conn.status == 403
    end

    # test "requires accepting ToS and PP", %{conn: conn, address: address} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = put(conn, Routes.user_address_path(conn, :update, user.id, address), address: @update_attrs)
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = put(conn, Routes.user_address_path(conn, :update, user.id, address), address: @update_attrs)
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  describe "delete address" do
    setup [:create_address]

    test "deletes chosen address", %{conn: conn, user: user, session: session, address: address} do
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.user_address_path(conn, :delete, user.id, address))
      assert response(conn, 204)

      conn = get(conn, Routes.user_address_path(conn, :show, user.id, address))
      assert conn.status == 404
    end

    test "Requires being authenticated", %{conn: conn, address: address} do
      conn = delete(conn, Routes.user_address_path(conn, :delete, "42", address))
      assert conn.status == 403
    end

    # If regular users should be allowed to create a address, then remove this test
    # test "won't work for regular user", %{conn: conn, address: address} do
    #   {:ok, conn, user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
    #   conn = delete(conn, Routes.user_address_path(conn, :delete, user.id, address))
    #   assert conn.status == 401
    # end

    # test "requires accepting ToS and PP", %{conn: conn, address: address} do
    #   {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    #   conn = Helpers.Accounts.put_token(conn, session.api_token)
    #   conn = delete(conn, Routes.user_address_path(conn, :delete, user.id, address))
    #   # We haven't accepted the terms of service yet so expect 461
    #   assert conn.status == 461

    #   {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
    #   conn = delete(conn, Routes.user_address_path(conn, :delete, user.id, address))
    #   # We haven't accepted the PP yet so expect 462
    #   assert conn.status == 462
    # end
  end

  defp create_address(_) do
    {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
    address = fixture(:address, user.id)
    %{user: user, session: session, address: address}
  end
end
