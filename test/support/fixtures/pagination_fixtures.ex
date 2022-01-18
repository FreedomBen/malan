defmodule Malan.PaginationFixtures do
  alias Malan.Accounts
  alias Malan.Test.Helpers

  def paginated_conn_fixture(%Plug.Conn{} = conn, params \\ %{}, assigns \\ %{}) do
    params =
      Map.merge(
        %{
          "page_num" => 3,
          "page_size" => 8
        },
        params
      )

    assigns = Map.merge(%{pagination_error: nil}, assigns)

    conn
    |> Map.merge(%{params: params, query_params: params, assigns: assigns})
  end

  def paginated_new_conn_fixture(attrs \\ %{}) do
    paginated_conn_fixture(
      %Plug.Conn{assigns: %{}},
      attrs
    )
  end
end
