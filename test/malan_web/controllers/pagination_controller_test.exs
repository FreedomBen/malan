defmodule MalanWeb.PaginationControllerTest do
  use MalanWeb.ConnCase, async: true

  alias Malan.Pagination
  alias MalanWeb.PaginationController
  alias Malan.PaginationFixtures

  alias Malan.Test.Utils, as: TestUtils

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
      assert conn.assigns.pagination_info.page_num == 2
      assert conn.assigns.pagination_info.page_size == 6
      assert conn.assigns.pagination_error == nil
    end
  end

  describe "#validate_pagination/2" do
    test "works", %{conn: conn} do
      assert %{assigns: %{pagination_info: %{page_num: 3, page_size: 8}}} =
               PaginationController.validate_pagination(
                 PaginationFixtures.paginated_conn_fixture(conn),
                 nil
               )

      assert %{assigns: %{pagination_info: %{page_num: 2, page_size: 6}}} =
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
            %{"page_num" => 0, "page_size" => Pagination.default_max_page_size() + 1}
          ),
          []
        )

      assert %{
               assigns: %{
                 pagination_info: nil,
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
    test "defaults the page num and size" do
      assert %{
               assigns: %{
                 pagination_error: nil,
                 pagination_info: %Pagination{
                   page_num: 0,
                   page_size: 10
                 }
               }
             } = PaginationController.require_pagination(%Plug.Conn{params: %{}})
    end

    test "validates pagination and check that it is required", %{conn: conn} do
      c1 = PaginationController.require_pagination(%Plug.Conn{params: %{"page_num" => 2}})

      assert %{
               assigns: %{
                 pagination_error: nil,
                 pagination_info: %Pagination{
                   page_num: 2,
                   page_size: 10
                 }
               }
             } = c1

      c2 = PaginationController.require_pagination(%Plug.Conn{params: %{"page_size" => 5}}, [])

      assert %{
               assigns: %{
                 pagination_error: nil,
                 pagination_info: %Pagination{
                   page_num: 0,
                   page_size: 5
                 }
               }
             } = c2

      c3 =
        PaginationController.require_pagination(%Plug.Conn{
          params: %{"page_num" => 6, "page_size" => 2}
        })

      assert %{
               assigns: %{
                 pagination_error: nil,
                 pagination_info: %Pagination{
                   page_num: 6,
                   page_size: 2
                 }
               }
             } = c3

      c4 =
        PaginationController.require_pagination(
          TestUtils.Controller.set_params(conn, %{
            "page_num" => -7,
            "page_size" => 2
          })
        )

      assert %{
               halted: true,
               assigns: %{
                 pagination_error: %Ecto.Changeset{
                   errors: [page_num: {"must be greater than or equal to %{number}", _}]
                 },
                 pagination_info: nil
               }
             } = c4

      c5 =
        PaginationController.require_pagination(
          TestUtils.Controller.set_params(conn, %{
            "page_num" => 7,
            "page_size" => 200
          })
        )

      assert %{
               halted: true,
               assigns: %{
                 pagination_error: %Ecto.Changeset{
                   errors: [page_size: {"must be less than or equal to %{number}", _}]
                 },
                 pagination_info: nil
               }
             } = c5

      c6 =
        PaginationController.require_pagination(
          TestUtils.Controller.set_params(conn, %{
            "page_num" => -7,
            "page_size" => 200
          })
        )

      assert %{
               halted: true,
               assigns: %{
                 pagination_error: %Ecto.Changeset{
                   errors: [
                     {:page_size, {"must be less than or equal to %{number}", _}},
                     {:page_num, {"must be greater than or equal to %{number}", _}}
                   ]
                 },
                 pagination_info: nil
               }
             } = c6
    end
  end

  describe "#extract_page_info/1" do
    test "#extract_page_info/1" do
      assert {:ok,
              %Pagination{page_num: 0, page_size: 15, default_page_size: 15, max_page_size: 20}} =
               PaginationController.extract_page_info(%Plug.Conn{params: %{}}, 15, 20)

      # params overwritten by extract_page_info args
      assert {:ok,
              %Pagination{page_num: 2, page_size: 7, default_page_size: 15, max_page_size: 20}} =
               PaginationController.extract_page_info(
                 %Plug.Conn{
                   params: %{
                     "page_num" => 2,
                     "page_size" => 7,
                     "max_page_size" => 30,
                     "default_page_size" => 28
                   }
                 },
                 15,
                 20
               )

      assert {:ok, %Pagination{page_num: 0, page_size: 5}} =
               PaginationController.extract_page_info(
                 %Plug.Conn{params: %{"page_size" => 5}},
                 15,
                 20
               )

      assert {:ok, %Pagination{page_num: 6, page_size: 2}} =
               PaginationController.extract_page_info(
                 %Plug.Conn{
                   params: %{"page_num" => 6, "page_size" => 2}
                 },
                 15,
                 20
               )

      assert {:error, %Ecto.Changeset{errors: [page_num: {_, _}]}} =
               PaginationController.extract_page_info(
                 %Plug.Conn{params: %{"page_num" => -1}},
                 15,
                 20
               )

      assert {:error, %Ecto.Changeset{errors: [page_size: {_, _}]}} =
               PaginationController.extract_page_info(
                 %Plug.Conn{params: %{"page_size" => -1}},
                 15,
                 20
               )

      assert {:error, %Ecto.Changeset{errors: [{:page_size, _}, {:page_num, _}]}} =
               PaginationController.extract_page_info(
                 %Plug.Conn{
                   params: %{"page_num" => -2, "page_size" => -1}
                 },
                 15,
                 20
               )
    end

    test "#extract_page_info/1 works" do
      assert {:ok,
              %Pagination{page_num: 5, page_size: 5, max_page_size: 20, default_page_size: 15}} ==
               PaginationController.extract_page_info(
                 %{"page_num" => 5, "page_size" => 5},
                 15,
                 20
               )
    end

    test "#extract_page_info/1 correct defaults when param not specified" do
      assert {:ok,
              %Pagination{
                page_num: 5,
                page_size: Pagination.default_page_size(),
                max_page_size: 20,
                default_page_size: Pagination.default_page_size()
              }} ==
               PaginationController.extract_page_info(%{"page_num" => "5"}, %Pagination{
                 max_page_size: 20
               })

      assert {:ok,
              %Pagination{
                page_num: 5,
                page_size: 7,
                max_page_size: Pagination.default_max_page_size(),
                default_page_size: 7
              }} ==
               PaginationController.extract_page_info(%{"page_num" => "5"}, %Pagination{
                 default_page_size: 7
               })

      assert {:ok,
              %Pagination{
                page_num: Pagination.default_page_num(),
                page_size: Pagination.default_page_size(),
                max_page_size: Pagination.default_max_page_size(),
                default_page_size: Pagination.default_page_size()
              }} ==
               PaginationController.extract_page_info(%{})
    end
  end
end
