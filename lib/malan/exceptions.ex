defmodule Malan.ObjectIsImmutable do
  defexception [:message]

  def exception(opts) do
    action = Keyword.get(opts, :action, nil)
    type = Keyword.get(opts, :type, nil)
    id = Keyword.get(opts, :id, nil)

    msg = """
    object of type "#{type}" with id "#{id}" is immutable.  Can't apply changes for action "#{action}"
    """

    %__MODULE__{message: msg}
  end
end

defmodule Malan.CantBeNil do
  defexception [:message]

  def exception(opts) do
    varname = Keyword.get(opts, :varname, nil)

    msg =
      case varname do
        nil -> "value was set to nil but cannot be"
        _ -> "variable '#{varname}' was nil but cannot be"
      end

    %__MODULE__{message: msg}
  end
end

defmodule Malan.Pagination.PageOutOfBounds do
  defexception [:message]

  def exception(opts) do
    table = Keyword.get(opts, :table, "(not specified)")
    page_num = Keyword.get(opts, :page_num, "(not specified)")
    page_size = Keyword.get(opts, :page_size, "(not specified)")

    msg =
      "Page specification was out of bounds. page_num: '#{page_num}', page_size: '#{page_size}', table: '#{table}'"

    if !!table,
      do:
        msg = "#{msg} Max page_size for table is '#{Malan.Pagination.max_page_size(table)}'"

    %__MODULE__{message: msg}
  end
end

# Note:  This is the same code as Ecto.NoResultsError
defmodule Malan.NoResultsError do
  defexception [:message]

  def exception(opts) do
    query = Keyword.fetch!(opts, :queryable) |> Ecto.Queryable.to_query()

    msg = """
    expected at least one result but got none in query:
    #{Inspect.Ecto.Query.to_string(query)}
    """

    %__MODULE__{message: msg}
  end
end
