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

# Note:  This is the same code as Ecto.NoResultsError
defmodule Malan.NoResultsError do
  defexception [:message]

  def exception(opts) do
    query = Keyword.fetch!(opts, :queryable) |> Ecto.Queryable.to_query

    msg = """
    expected at least one result but got none in query:
    #{Inspect.Ecto.Query.to_string(query)}
    """

    %__MODULE__{message: msg}
  end
end
