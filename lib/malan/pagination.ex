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
  @default_max_page_size 10

  defguard valid_page(page_num, page_size)
           when is_integer(page_num) and is_integer(page_size) and page_num >= 0 and
                  page_size >= 0

  def default_page_num, do: @default_page_num
  def default_page_size, do: @default_page_size
  def default_max_page_size, do: @default_max_page_size

  embedded_schema do
    field :page_num, :integer
    field :page_size, :integer
    field :default_page_size, :integer
    field :max_page_size, :integer
  end

  def changeset(pagination, attrs) do
    pagination
    |> cast(attrs, [:page_num, :page_size])
    |> set_default_page_size()
    |> set_max_page_size()
    |> infer_default_page_num()
    |> infer_default_page_size()
    |> validate_page_num()
    |> validate_page_size()
  end

  def set_default_page_size(changeset) do
    case get_field(changeset, :default_page_size) do
      nil -> put_change(changeset, :default_page_size, @default_page_size)
        _ -> changeset
    end
  end

  def set_max_page_size(changeset) do
    case get_field(changeset, :max_page_size) do
      nil -> put_change(changeset, :max_page_size, @default_max_page_size)
        _ -> changeset
    end
  end

  def infer_default_page_num(changeset) do
    case get_field(changeset, :page_num) do
      nil -> put_change(changeset, :page_num, @default_page_num)
        _ -> changeset
    end
  end

  def infer_default_page_size(changeset) do
    case get_field(changeset, :page_size) do
      nil -> put_change(changeset, :page_size, get_field(changeset, :default_page_size))
        _ -> changeset
    end
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

  def validate_page_size(page_size) when is_integer(page_size) do
    cond do
      page_size >= 0 -> {:ok, page_size}
      true -> {:error, page_size}
    end
  end

  def validate_page_size(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_number(:page_size, greater_than_or_equal_to: 0)
    |> validate_number(:page_size, less_than_or_equal_to: get_field(changeset, :max_page_size))
  end

  @doc ~S"""
  Validate the specified page number.

  Returns `page_size` or raises `Malan.PageOutOfBounds`
  """
  def validate_page_size!(page_size) when is_integer(page_size) do
    case validate_page_size(page_size) do
      {:ok, _} -> page_size
      {:error, _} -> raise PageOutOfBounds, page_size: page_size
    end
  end

  def num_pages(total_count, page_size) do
    div(total_count, page_size) + 1
  end

end
