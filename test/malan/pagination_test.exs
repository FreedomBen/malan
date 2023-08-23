defmodule Malan.PaginationTest do
  alias Malan.Pagination
  alias Malan.Pagination.PageOutOfBounds

  use ExUnit.Case, async: true

  # Suggest including DataCase and refactorng tests below to
  # make use of `errors_on(changeset)` for easier code
  # use Malan.DataCase, async: true

  describe "Malan.Pagination" do
    test "#validate_page_num/1" do
      assert {:ok, 0} = Pagination.validate_page_num(0)
      assert {:ok, 10} = Pagination.validate_page_num(10)
      assert {:error, -1} = Pagination.validate_page_num(-1)
    end

    test "#validate_page_num!/1" do
      assert true == Pagination.validate_page_num!(0)
      assert true == Pagination.validate_page_num!(10)

      assert_raise PageOutOfBounds, fn ->
        Pagination.validate_page_num!(-1)
      end
    end

    test "#changeset/2 for page_num" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 5},
               data: %Pagination{}
             } = p2 = Pagination.changeset(%Pagination{}, %{page_num: 5})

      assert {:ok, %Pagination{page_num: 5, page_size: 10}} =
               Ecto.Changeset.apply_action(p2, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: -2},
               data: %Pagination{},
               errors: [page_num: {"must be greater than or equal to %{number}", _}]
             } = p3 = Pagination.changeset(%Pagination{}, %{page_num: -2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p3, :update)
    end

    test "#changeset/2 for page_num wrong type" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 2},
               data: %Pagination{}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_num: "2"})

      assert {:ok, %Pagination{page_num: 2, page_size: 10}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{},
               data: %Pagination{},
               errors: [page_num: {"is invalid", _}]
             } = p2 = Pagination.changeset(%Pagination{}, %{page_num: "marshall"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_size" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_size: 5},
               data: %Pagination{}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_size: 5})

      assert {:ok, %Pagination{page_num: 0, page_size: 5}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_size: -2},
               data: %Pagination{}
             } = p2 = Pagination.changeset(%Pagination{}, %{page_size: -2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_size too large" do
      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_size: 30},
               data: %Pagination{},
               errors: [page_size: {_, _}]
             } = p1 = Pagination.changeset(%Pagination{}, %{page_size: 30})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_size: -2},
               data: %Pagination{}
             } = p2 = Pagination.changeset(%Pagination{}, %{page_size: -2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_size wrong type" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_size: 2},
               data: %Pagination{}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_size: "2"})

      assert {:ok, %Pagination{page_num: 0, page_size: 2}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{},
               data: %Pagination{},
               errors: [page_size: {"is invalid", _}]
             } = p2 = Pagination.changeset(%Pagination{}, %{page_size: "marshall"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_num and page_size" do
      assert %Ecto.Changeset{
               valid?: true,
               data: %Pagination{},
               changes: %{}
             } = p1 = Pagination.changeset(%Pagination{}, %{})

      assert {:ok, %Pagination{page_num: 0, page_size: 10}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 2, page_size: 5},
               data: %Pagination{}
             } =
               p2 =
               Pagination.changeset(%Pagination{}, %{page_num: 2, page_size: 5})

      assert {:ok, %Pagination{page_num: 2, page_size: 5}} =
               Ecto.Changeset.apply_action(p2, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: -5, page_size: 2},
               data: %Pagination{}
             } =
               p3 =
               Pagination.changeset(%Pagination{}, %{page_num: -5, page_size: 2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p3, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: 3, page_size: -2},
               data: %Pagination{}
             } =
               p4 =
               Pagination.changeset(%Pagination{}, %{page_num: 3, page_size: -2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p4, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: -3, page_size: -2},
               data: %Pagination{}
             } = p5 = Pagination.changeset(%Pagination{}, %{page_num: -3, page_size: -2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p5, :update)
    end

    test "#changeset/2 for page_num and page_size wrong type" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 4, page_size: 2},
               data: %Pagination{}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_num: "4", page_size: "2"})

      assert {:ok, %Pagination{page_num: 4, page_size: 2}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{},
               data: %Pagination{},
               errors: [{:page_num, {"is invalid", _}}, {:page_size, {"is invalid", _}}]
             } =
               p2 =
               Pagination.changeset(%Pagination{}, %{page_num: "cliff", page_size: "marshall"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#validate_page_num/1 with changeset" do
      assert true ==
               Pagination.validate_page_num(Ecto.Changeset.change(%Pagination{}, %{})).valid?

      assert true ==
               Pagination.validate_page_num(Ecto.Changeset.change(%Pagination{}, %{page_num: 5})).valid?

      assert false ==
               Pagination.validate_page_num(Ecto.Changeset.change(%Pagination{}, %{page_num: -5})).valid?
    end

    test "#validate_page_size/1 with changeset" do
      assert true ==
               Pagination.validate_page_size(
                 Ecto.Changeset.change(%Pagination{}, %{})
                 |> Pagination.set_max_page_size()
               ).valid?

      assert true ==
               Pagination.validate_page_size(
                 Ecto.Changeset.change(%Pagination{}, %{page_size: 5})
                 |> Pagination.set_max_page_size()
               ).valid?

      assert false ==
               Pagination.validate_page_size(
                 Ecto.Changeset.change(%Pagination{}, %{page_size: -5})
                 |> Pagination.set_max_page_size()
               ).valid?
    end
  end
end
