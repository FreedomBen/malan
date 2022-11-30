defmodule <%= inspect context.module %> do
  @moduledoc """
  The <%= context.name %> context.
  """

  import Ecto.Query, warn: false
  import <%= inspect context.base_module %>.Pagination, only: [valid_page: 2]
  alias <%= inspect schema.repo %>
end
