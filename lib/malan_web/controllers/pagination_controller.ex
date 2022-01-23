defmodule Malan.PaginationController do
  import Plug.Conn
  import Malan.Utils.Phoenix.Controller

  import Ecto.Changeset, only: [apply_action: 2]

  require Logger

  alias Malan.Pagination

  @doc """
  Validate that the current user is authenticated
  """
  def is_paginated(conn, _opts) do
    Logger.debug("[is_paginated]: Validating pagination params")

    case conn.assigns do
      %{pagination_error: nil} -> conn
      %{pagination_error: {:error, :page_num}} -> halt_status(conn, 422)
      %{pagination_error: {:error, :page_size}} -> halt_status(conn, 422)
      _ -> halt_status(conn, 422)
    end
  end

  @doc """
  validate_pagination/2 is a plug function that will:

  1.  Take in a conn
  2.  Extract the page parameters
  3.  If valid, add the page num and page size to conn.assigns
  4.  If invalid will halt the connection

  Returns `conn`
  """
  def validate_pagination(conn, _opts) do
    with {:ok, pagination_info} <- extract_page_info(conn) do
      conn
      |> assign(:pagination_error, nil)
      |> assign(:pagination_info, pagination_info)
    else
      {:error, changeset} ->
        Logger.info("[validate_pagination]: pagination error: #{changeset}")

        conn
        |> assign(:pagination_error, changeset)
        |> assign(:pagination_info, nil)
    end
  end

  def require_pagination(conn), do: require_pagination(conn, nil)

  def require_pagination(conn, opts) do
    conn
    |> validate_pagination(opts)
    |> is_paginated(opts)
  end

  def extract_page_info(%Plug.Conn{params: params}) do
    extract_page_info(params)
  end

  def extract_page_info(params) do
    case Pagination.changeset(%Pagination{}, params) |> apply_action(:update) do
      {:ok, %Pagination{} = p} -> {:ok, p}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Take a `%Plug.Conn{}` called `conn` and return `{page_num, page_size}`
  """
  def pagination_info(conn) do
    {conn.assigns.pagination_info.page_num, conn.assigns.pagination_info.page_size}
  end
end
