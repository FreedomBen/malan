defmodule MalanWeb.TransactionControllerTest do
  use MalanWeb.ConnCase

  #import Malan.AccountsFixtures

  alias Malan.Accounts.Transaction

  alias Malan.Test.Helpers

  @create_attrs %{
    "type" => "some type",
    "verb" => "some verb",
    "what" => "some what",
    "when" => ~U[2021-12-22 21:02:00Z]
  }
  @update_attrs %{
    "type" => "some updated type",
    "verb" => "some updated verb",
    "what" => "some updated what",
    "when" => ~U[2021-12-23 21:02:00Z]
  }
  @invalid_attrs %{type: nil, verb: nil, what: nil, when: nil}

  def fixture(:transaction) do
    {:ok, transaction} = Malan.Accounts.create_transaction(@create_attrs)
    transaction
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all transactions", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.transaction_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :index))
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.transaction_path(conn, :index))
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = get(conn, Routes.transaction_path(conn, :index))
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "show" do
    test "gets transaction", %{conn: conn} do
      transaction = fixture(:transaction)
      id = transaction.id
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = get(conn, Routes.transaction_path(conn, :show, id))
      assert %{
               "id" => ^id,
               "type" => "some type",
               "verb" => "some verb",
               "what" => "some what",
               "when" => "2021-12-22T21:02:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :show, "42"))
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = get(conn, Routes.transaction_path(conn, :show, user.id))
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = get(conn, Routes.transaction_path(conn, :show, user.id))
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "create transaction" do
    test "renders transaction when data is valid", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.transaction_path(conn, :create), transaction: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.transaction_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "type" => "some type",
               "verb" => "some verb",
               "what" => "some what",
               "when" => "2021-12-22T21:02:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.transaction_path(conn, :create), transaction: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    # If regular users should be allowed to create a transaction, then remove this test
    test "won't work for regular user", %{conn: conn} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = post(conn, Routes.transaction_path(conn, :create), transaction: @create_attrs)
      assert conn.status == 401
    end

    test "requires being authenticated", %{conn: conn} do
      conn = post(conn, Routes.transaction_path(conn, :create), transaction: @create_attrs)
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = post(conn, Routes.transaction_path(conn, :create), transaction: @create_attrs)
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = post(conn, Routes.transaction_path(conn, :create), transaction: @create_attrs)
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "update transaction" do
    setup [:create_transaction]

    test "renders transaction when data is valid", %{conn: conn, transaction: %Transaction{id: id} = transaction} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.transaction_path(conn, :update, transaction), transaction: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.transaction_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "type" => "some updated type",
               "verb" => "some updated verb",
               "what" => "some updated what",
               "when" => "2021-12-23T21:02:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, transaction: transaction} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.transaction_path(conn, :update, transaction), transaction: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    # If regular users should be allowed to create a transaction, then remove this test
    test "won't work for regular user", %{conn: conn, transaction: transaction} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = put(conn, Routes.transaction_path(conn, :update, transaction), transaction: @update_attrs)
      assert conn.status == 401
    end

    test "requires being authenticated", %{conn: conn, transaction: _transaction} do
      conn = put(conn, Routes.transaction_path(conn, :update, "42"), transaction: @update_attrs)
      assert conn.status == 403
    end

    test "requires accepting ToS and PP", %{conn: conn, transaction: transaction} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = put(conn, Routes.transaction_path(conn, :update, transaction), transaction: @update_attrs)
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = put(conn, Routes.transaction_path(conn, :update, transaction), transaction: @update_attrs)
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  describe "delete transaction" do
    setup [:create_transaction]

    test "deletes chosen transaction", %{conn: conn, transaction: transaction} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.transaction_path(conn, :delete, transaction))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.transaction_path(conn, :show, transaction))
      end
    end

    test "Requires being authenticated", %{conn: conn, transaction: transaction} do
      conn = delete(conn, Routes.transaction_path(conn, :delete, transaction))
      assert conn.status == 403
    end

    # If regular users should be allowed to create a transaction, then remove this test
    test "won't work for regular user", %{conn: conn, transaction: transaction} do
      {:ok, conn, _user, _session} = Helpers.Accounts.regular_user_session_conn(conn)
      conn = delete(conn, Routes.transaction_path(conn, :delete, transaction))
      assert conn.status == 401
    end

    test "requires accepting ToS and PP", %{conn: conn, transaction: transaction} do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()
      conn = Helpers.Accounts.put_token(conn, session.api_token)
      conn = delete(conn, Routes.transaction_path(conn, :delete, transaction))
      # We haven't accepted the terms of service yet so expect 461
      assert conn.status == 461

      {:ok, _user} = Helpers.Accounts.accept_user_tos(user, true)
      conn = delete(conn, Routes.transaction_path(conn, :delete, transaction))
      # We haven't accepted the PP yet so expect 462
      assert conn.status == 462
    end
  end

  defp create_transaction(_) do
    transaction = fixture(:transaction)
    %{transaction: transaction}
  end
end
