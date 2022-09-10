defmodule Malan.PaginationTest do
  alias Malan.Pagination
  alias Malan.Pagination.PageOutOfBounds

  use ExUnit.Case, async: true

  # Suggest including DataCase and refactorng tests below to
  # make use of `errors_on(changeset)` for easier code
  # use Malan.DataCase, async: true

  describe "Malan.Pagination" do
    test "#max_page_size/1" do
      assert 10 == Pagination.max_page_size(:users)
      assert 20 == Pagination.max_page_size(:sessions)
      assert 10 == Pagination.max_page_size(:posts)
      assert 10 == Pagination.max_page_size(nil)
      assert Pagination.max_page_size() == Pagination.max_page_size(nil)
    end

    test "#get_table/1 changeset" do
      assert "users" =
               Pagination.changeset(%Pagination{}, %{table: "users"}) |> Pagination.get_table()

      assert "sessions" =
               Pagination.changeset(%Pagination{}, %{table: "sessions"}) |> Pagination.get_table()

      assert nil ==
               Pagination.changeset(%Pagination{}, %{}) |> Pagination.get_table()
    end

    test "#get_table/1 table" do
      assert %{max_page_size: 10} = Pagination.get_table(:users)
      assert %{max_page_size: 20} = Pagination.get_table(:sessions)
      assert %{max_page_size: 10} = Pagination.get_table(:notarealtable)

      assert %{max_page_size: 10} = Pagination.get_table("users")
      assert %{max_page_size: 20} = Pagination.get_table("sessions")
      assert %{max_page_size: 10} = Pagination.get_table("notarealtable")

      assert %{max_page_size: 10} = Pagination.get_table(nil)
      assert %{max_page_size: 10} = Pagination.get_table()
    end

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

    test "#validate_page_size/1" do
      assert {:ok, 10} = Pagination.validate_page_size(10)
      assert {:error, 0} = Pagination.validate_page_size(0)
      assert {:error, -1} = Pagination.validate_page_size(-1)
    end

    test "#changeset/2 for page_num" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 5},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p2 = Pagination.changeset(%Pagination{}, %{page_num: 5})

      assert {:ok, %Pagination{page_num: 5, page_size: 10, table: nil}} =
               Ecto.Changeset.apply_action(p2, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: -2},
               data: %Pagination{page_num: 0, page_size: 10, table: nil},
               errors: [page_num: {"must be greater than or equal to %{number}", _}]
             } = p3 = Pagination.changeset(%Pagination{}, %{page_num: -2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p3, :update)
    end

    test "#changeset/2 for page_num wrong type" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 2, table: "users"},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_num: "2", table: "users"})

      assert {:ok, %Pagination{page_num: 2, page_size: 10, table: "users"}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{},
               data: %Pagination{page_num: 0, page_size: 10, table: nil},
               errors: [page_num: {"is invalid", _}]
             } = p2 = Pagination.changeset(%Pagination{}, %{page_num: "marshall", table: "users"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for invalid table" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p1 = Pagination.changeset(%Pagination{}, %{table: "notarealtable"})

      assert {:ok, %Pagination{page_num: 0, page_size: 10, table: nil}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p2 = Pagination.changeset(%Pagination{}, %{table: nil})

      assert {:ok, %Pagination{page_num: 0, page_size: 10, table: nil}} =
               Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_size" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_size: 5, table: "sessions"},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_size: 5, table: "sessions"})

      assert {:ok, %Pagination{page_num: 0, page_size: 5, table: "sessions"}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_size: -2},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p2 = Pagination.changeset(%Pagination{}, %{page_size: -2, table: "sessions"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_size too large" do
      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_size: 30, table: "sessions"},
               data: %Pagination{page_num: 0, page_size: 10},
               errors: [page_size: {_, _}]
             } = p1 = Pagination.changeset(%Pagination{}, %{page_size: 30, table: "sessions"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_size: -2, table: "sessions"},
               data: %Pagination{page_num: 0, page_size: 10}
             } = p2 = Pagination.changeset(%Pagination{}, %{page_size: -2, table: "sessions"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_size wrong type" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_size: 2},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_size: "2"})

      assert {:ok, %Pagination{page_num: 0, page_size: 2, table: nil}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{},
               data: %Pagination{page_num: 0, page_size: 10, table: nil},
               errors: [page_size: {"is invalid", _}]
             } = p2 = Pagination.changeset(%Pagination{}, %{page_size: "marshall"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for page_num and page_size" do
      assert %Ecto.Changeset{
               valid?: true,
               data: %Pagination{page_num: 0, page_size: 10, table: nil},
               changes: %{table: "users"}
             } = p1 = Pagination.changeset(%Pagination{}, %{table: "users"})

      assert {:ok, %Pagination{page_num: 0, page_size: 10, table: "users"}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 2, page_size: 5, table: "users"},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } =
               p2 =
               Pagination.changeset(%Pagination{}, %{page_num: 2, page_size: 5, table: "users"})

      assert {:ok, %Pagination{page_num: 2, page_size: 5, table: "users"}} =
               Ecto.Changeset.apply_action(p2, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: -5, page_size: 2, table: "users"},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } =
               p3 =
               Pagination.changeset(%Pagination{}, %{page_num: -5, page_size: 2, table: "users"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p3, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: 3, page_size: -2, table: "users"},
               data: %Pagination{page_num: 0, page_size: 10}
             } =
               p4 =
               Pagination.changeset(%Pagination{}, %{page_num: 3, page_size: -2, table: "users"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p4, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{page_num: -3, page_size: -2},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p5 = Pagination.changeset(%Pagination{}, %{page_num: -3, page_size: -2})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p5, :update)
    end

    test "#changeset/2 for page_num and page_size wrong type" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{page_num: 4, page_size: 2},
               data: %Pagination{page_num: 0, page_size: 10, table: nil}
             } = p1 = Pagination.changeset(%Pagination{}, %{page_num: "4", page_size: "2"})

      assert {:ok, %Pagination{page_num: 4, page_size: 2, table: nil}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{},
               data: %Pagination{page_num: 0, page_size: 10, table: nil},
               errors: [{:page_num, {"is invalid", _}}, {:page_size, {"is invalid", _}}]
             } =
               p2 =
               Pagination.changeset(%Pagination{}, %{page_num: "cliff", page_size: "marshall"})

      assert {:error, %Ecto.Changeset{}} = Ecto.Changeset.apply_action(p2, :update)
    end

    test "#changeset/2 for table" do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{table: "users"},
               data: %Pagination{page_num: 0, page_size: 10, table: nil, max_page_size: 10}
             } = p1 = Pagination.changeset(%Pagination{}, %{table: "users"})

      assert {:ok, %Pagination{page_num: 0, page_size: 10, table: "users"}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{},
               data: %Pagination{page_num: 0, page_size: 10, table: nil, max_page_size: 10}
             } = p1 = Pagination.changeset(%Pagination{}, %{table: nil})

      assert {:ok, %Pagination{page_num: 0, page_size: 10, table: nil}} =
               Ecto.Changeset.apply_action(p1, :update)

      assert %Ecto.Changeset{
               valid?: false,
               changes: %{},
               data: %Pagination{page_num: 0, page_size: 10, table: nil, max_page_size: 10},
               errors: [{:table, {"is invalid", _}}]
             } = p2 = Pagination.changeset(%Pagination{}, %{table: :sessions})

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
               Pagination.validate_page_size(Ecto.Changeset.change(%Pagination{}, %{})).valid?

      assert true ==
               Pagination.validate_page_size(
                 Ecto.Changeset.change(%Pagination{}, %{page_size: 5})
               ).valid?

      assert false ==
               Pagination.validate_page_size(
                 Ecto.Changeset.change(%Pagination{}, %{page_size: -5})
               ).valid?
    end

    test "#validate_page_size/2" do
      assert {:ok, 10} = Pagination.validate_page_size(:users, 10)
      assert {:ok, 10} = Pagination.validate_page_size(:sessions, 10)
      assert {:ok, 10} = Pagination.validate_page_size(:posts, 10)

      assert {:error, 100} = Pagination.validate_page_size(:users, 100)
      assert {:error, 100} = Pagination.validate_page_size(:sessions, 100)
      assert {:error, 100} = Pagination.validate_page_size(:posts, 100)

      assert {:error, 0} = Pagination.validate_page_size(:users, 0)
      assert {:error, -1} = Pagination.validate_page_size(:users, -1)
    end

    test "#validate_page_size!/1" do
      assert 10 == Pagination.validate_page_size!(10)
      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_size!(0) end
      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_size!(-1) end
    end

    test "#validate_page_size!/2" do
      assert 10 = Pagination.validate_page_size!(:users, 10)
      assert 10 = Pagination.validate_page_size!(:sessions, 10)
      assert 10 = Pagination.validate_page_size!(:posts, 10)

      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_size!(:users, 100) end
      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_size!(:sessions, 100) end
      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_size!(:posts, 100) end

      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_size!(:users, 0) end
      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_size!(:users, -1) end
    end

    test "#validate_page_num_size/2" do
      assert {:ok, 0, 5} = Pagination.validate_page_num_size(:users, 0, 5)
      assert {:ok, 4, 7} = Pagination.validate_page_num_size(:sessions, 4, 7)
      assert {:ok, 8, 10} = Pagination.validate_page_num_size(:posts, 8, 10)

      assert {:error, 2, 100} == Pagination.validate_page_num_size(:users, 2, 100)
      assert {:error, 2, 100} == Pagination.validate_page_num_size(:sessions, 2, 100)
      assert {:error, 2, 100} == Pagination.validate_page_num_size(:posts, 2, 100)

      assert {:error, -1, 10} == Pagination.validate_page_num_size(:users, -1, 10)

      assert {:error, -2, 0} == Pagination.validate_page_num_size(:users, -2, 0)
      assert {:error, -99999, -1} == Pagination.validate_page_num_size(:users, -99999, -1)
    end

    test "#validate_page_num_size!/3" do
      assert true = Pagination.validate_page_num_size!(:users, 0, 5)
      assert true = Pagination.validate_page_num_size!(:sessions, 4, 7)
      assert true = Pagination.validate_page_num_size!(:posts, 8, 10)

      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_num_size!(:users, 2, 100) end

      assert_raise PageOutOfBounds, fn ->
        Pagination.validate_page_num_size!(:sessions, 2, 100)
      end

      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_num_size!(:posts, 2, 100) end

      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_num_size!(:users, -1, 10) end

      assert_raise PageOutOfBounds, fn -> Pagination.validate_page_num_size!(:users, -2, 0) end

      assert_raise PageOutOfBounds, fn ->
        Pagination.validate_page_num_size!(:users, -99999, -1)
      end
    end
  end
end
