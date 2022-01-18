defmodule Malan.Pagination do
  @moduledoc """
  Malan.Pagination is used for validating pagination parameters.

  It is not actually stored in the database.  The changeset pattern
  is used for convenience.  See:  https://hexdocs.pm/ecto/Ecto.Changeset.html#module-schemaless-changesets
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Malan.Pagination.PageOutOfBounds

  @default_page_num 0
  @default_page_size 10
  @default_max_size 10

  @valid_tables %{
    nil => %{max_page_size: @default_max_size},
    "users" => %{max_page_size: 10},
    "sessions" => %{max_page_size: 20},
    "phone_numbers" => %{max_page_size: 10},
    "addresses" => %{max_page_size: 10},
    "posts" => %{max_page_size: 10}
  }

  defguard valid_page(page_num, page_size)
           when is_integer(page_num) and is_integer(page_size) and page_num >= 0 and
                  page_size >= 0

  def default_page_num, do: @default_page_num
  def default_page_size, do: @default_page_size
  def default_max_size, do: @default_max_size

  embedded_schema do
    field :table, :string, default: nil
    field :page_num, :integer, default: 0
    field :page_size, :integer, default: 10
    field :max_page_size, :integer, default: 10
  end

  def changeset(pagination, attrs) do
    pagination
    |> cast(attrs, [:page_num, :page_size, :table])
    |> validate_table()
    |> inject_max_page_size()
    |> validate_page_num()
    |> validate_page_size()
  end

  def get_table(%Ecto.Changeset{} = cs), do: get_field(cs, :table)
  def get_table(table) when is_atom(table), do: get_table(Atom.to_string(table))

  def get_table(table \\ nil) do
    case valid_table?(table) do
      true -> Map.get(@valid_tables, table)
      false -> Map.get(@valid_tables, nil)
    end
  end

  def valid_table?(table), do: table in Map.keys(@valid_tables)

  def max_page_size(table) when is_atom(table), do: max_page_size(Atom.to_string(table))

  def max_page_size(table \\ nil) do
    case valid_table?(table) do
      true -> get_table(table).max_page_size
      false -> @default_max_size
    end
  end

  def validate_table(changeset) do
    case get_field(changeset, :table) in Map.keys(@valid_tables) do
      true -> changeset
      false -> put_change(changeset, :table, nil)
    end
  end

  def inject_max_page_size(changeset) do
    put_change(changeset, :max_page_size, max_page_size(get_table(changeset)))
  end

  def validate_page_num(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_number(:page_num, greater_than_or_equal_to: 0)
  end

  @doc ~S"""
  Validate the specified page number.

  Returns `{:ok, page_num}` or `{:error, page_num}`
  """
  def validate_page_num(page_num) do
    cond do
      page_num >= 0 -> {:ok, page_num}
      true -> {:error, page_num}
    end
  end

  @doc ~S"""
  Validate the specified page number.

  Returns `page_num` or raises `Malan.PageOutOfBounds`
  """
  def validate_page_num!(page_num) do
    case validate_page_num(page_num) do
      {:ok, _} -> true
      {:error, _} -> raise PageOutOfBounds, page_num: page_num
    end
  end

  def validate_page_size(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_number(:page_size, greater_than_or_equal_to: 0)
    |> validate_number(:page_size, less_than_or_equal_to: max_page_size(get_table(changeset)))
  end

  @doc ~S"""
  Validate the specified page size.

  Returns `{:ok, page_size}` or `{:error, page_size}`
  """
  def validate_page_size(page_size) do
    _validate_page_size(page_size, max_page_size())
  end

  @doc ~S"""
  Validate the specified page number.

  Returns `page_size` or raises `Malan.PageOutOfBounds`
  """
  def validate_page_size!(page_size) do
    case validate_page_size(page_size) do
      {:ok, _} -> page_size
      {:error, _} -> raise PageOutOfBounds, page_size: page_size
    end
  end

  @doc ~S"""
  Validate the specified page size.

  Returns `{:ok, page_size}` or `{:error, page_size}`
  """
  def validate_page_size(table, page_size) do
    _validate_page_size(page_size, max_page_size(table))
  end

  @doc ~S"""
  Validate the specified page number.

  Returns `page_size` or raises `Malan.PageOutOfBounds`
  """
  def validate_page_size!(table, page_size) do
    case validate_page_size(table, page_size) do
      {:ok, _} -> page_size
      {:error, _} -> raise PageOutOfBounds, page_size: page_size, table: table
    end
  end

  def validate_page_num_size(page_num, page_size) do
    with {:ok, _} <- validate_page_num(page_num),
         {:ok, _} <- validate_page_size(page_size) do
      {:ok, page_num, page_size}
    else
      _ -> {:error, page_num, page_size}
    end
  end

  def validate_page_num_size!(page_num, page_size) do
    case validate_page_num_size(page_num, page_size) do
      {:ok, _, _} -> true
      {:error, _, _} -> false
    end
  end

  def validate_page_num_size(table, page_num, page_size) do
    with {:ok, _} <- validate_page_num(page_num),
         {:ok, _} <- validate_page_size(table, page_size) do
      {:ok, page_num, page_size}
    else
      _ -> {:error, page_num, page_size}
    end
  end

  def validate_page_num_size!(table, page_num, page_size) do
    case validate_page_num_size(table, page_num, page_size) do
      {:ok, _, _} ->
        true

      {:error, _, _} ->
        raise PageOutOfBounds, page_num: page_num, page_size: page_size, table: table
    end
  end

  defp _validate_page_size(page_size, max_size) do
    cond do
      page_size > 0 && page_size <= max_size -> {:ok, page_size}
      true -> {:error, page_size}
    end
  end
end
