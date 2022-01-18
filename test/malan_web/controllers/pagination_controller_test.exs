defmodule MalanWeb.PaginationControllerTest do
  use MalanWeb.ConnCase, async: true

  # alias Malan.Accounts
  # alias Malan.Accounts.{User, Session}

  alias Malan.Test.Helpers
  alias Malan.AuthController
  alias Malan.PaginationController
  alias Malan.PaginationFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  def validate_pagination(conn) do
    PaginationController.validate_pagination(
      PaginationFixtures.paginated_conn_fixture(
        conn,
        %{"page_num" => 2, "page_size" => 6}
      ),
      nil
    )
  end

  describe "#is_paginated/2" do
    test "works", %{conn: conn} do
      assert false ==
               PaginationController.is_paginated(
                 PaginationFixtures.paginated_conn_fixture(conn),
                 nil
               ).halted
    end

    test "works 2", %{conn: conn} do
      conn = validate_pagination(conn)
      assert conn.assigns.pagination_error == nil
      assert conn.assigns.pagination_page_num == 2
      assert conn.assigns.pagination_page_size == 6
      assert conn.assigns.pagination_error == nil
    end
  end

  describe "#validate_pagination/2" do
    test "works", %{conn: conn} do
      assert %{assigns: %{pagination_page_num: 3, pagination_page_size: 8}} =
               PaginationController.validate_pagination(
                 PaginationFixtures.paginated_conn_fixture(conn),
                 nil
               )

      assert %{assigns: %{pagination_page_num: 2, pagination_page_size: 6}} =
               PaginationController.validate_pagination(
                 PaginationFixtures.paginated_conn_fixture(
                   conn,
                   %{"page_num" => 2, "page_size" => 6}
                 ),
                 nil
               )
    end

    test "Properly sets error", %{conn: conn} do
      conn =
        PaginationController.validate_pagination(
          PaginationFixtures.paginated_conn_fixture(
            conn,
            %{"page_num" => 0, "page_size" => 106}
          ),
          nil
        )

      assert %{
               assigns: %{
                 pagination_page_num: nil,
                 pagination_page_size: nil,
                 pagination_error: %Ecto.Changeset{
                   errors: [
                     page_size:
                       {"must be less than or equal to %{number}",
                        [validation: :number, kind: :less_than_or_equal_to, number: 10]}
                   ]
                 }
               }
             } = conn
    end
  end

  describe "#require_pagination/2" do
    test "validates pagination and check that it is required", %{conn: conn} do
      # TODO
      # assert false
    end
  end

  describe "#extract_page_info/1" do
    test "#extract_page_info/1" do
      assert {:ok, 0, 10} = PaginationController.extract_page_info(%Plug.Conn{params: %{}})

      assert {:ok, 2, 10} =
               PaginationController.extract_page_info(%Plug.Conn{params: %{"page_num" => 2}})

      assert {:ok, 0, 5} =
               PaginationController.extract_page_info(%Plug.Conn{params: %{"page_size" => 5}})

      assert {:ok, 6, 2} =
               PaginationController.extract_page_info(%Plug.Conn{
                 params: %{"page_num" => 6, "page_size" => 2}
               })

      assert {:error, %Ecto.Changeset{errors: [page_num: {_, _}]}} =
               PaginationController.extract_page_info(%Plug.Conn{params: %{"page_num" => -1}})

      assert {:error, %Ecto.Changeset{errors: [page_size: {_, _}]}} =
               PaginationController.extract_page_info(%Plug.Conn{params: %{"page_size" => -1}})

      assert {:error, %Ecto.Changeset{errors: [{:page_size, _}, {:page_num, _}]}} =
               PaginationController.extract_page_info(%Plug.Conn{
                 params: %{"page_num" => -2, "page_size" => -1}
               })
    end

    test "#extract_page_info/1 works" do
      assert {:ok, 5, 5} ==
               PaginationController.extract_page_info(%{"page_num" => 5, "page_size" => 5})
    end

    test "#extract_page_info/1 correct defaults when param not specified" do
      assert {:ok, 5, 10} == PaginationController.extract_page_info(%{"page_num" => "5"})
      assert {:ok, 0, 5} == PaginationController.extract_page_info(%{"page_size" => "5"})
      assert {:ok, 0, 10} == PaginationController.extract_page_info(%{})
    end
  end
end
