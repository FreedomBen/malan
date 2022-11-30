defmodule MalanWeb.PaginationController do
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
  def validate_pagination(conn, opts \\ []) do
    {default_page_size, max_page_size} =
      cond do
        is_list(opts) ->
          {
            Keyword.get(opts, :default_page_size, nil),
            Keyword.get(opts, :max_page_size, nil)
          }

        true ->
          {nil, nil}
      end

    with {:ok, pagination_info} <- extract_page_info(conn, default_page_size, max_page_size) do
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

  def extract_page_info(%Plug.Conn{params: params}, %Pagination{} = pagination) do
    extract_page_info(params, pagination)
  end

  def extract_page_info(%{} = params, %Pagination{} = pagination) do
    pagination
    |> Pagination.changeset(params)
    |> apply_action(:update)
    |> case do
      {:ok, pagination} -> {:ok, pagination}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def extract_page_info(%Plug.Conn{params: params}, default_page_size, max_page_size) do
    extract_page_info(params, %Pagination{
      max_page_size: max_page_size,
      default_page_size: default_page_size
    })
  end

  def extract_page_info(%{} = params, default_page_size, max_page_size) do
    extract_page_info(params, %Pagination{
      max_page_size: max_page_size,
      default_page_size: default_page_size
    })
  end

  def extract_page_info(%{} = params) do
    extract_page_info(params, %Pagination{})
  end

  @doc """
  Take a `%Plug.Conn{}` called `conn` and return `{page_num, page_size}`
  """
  def pagination_info(conn) do
    case conn.assigns do
      %{pagination_info: %{page_num: page_num, page_size: page_size}} ->
        {page_num, page_size}

      _ ->
        Logger.warning(
          "[pagination_info]: pagination info retrieved from conn that hasn't been through the plug `validate_pagination` or `require_pagination`. There may be an endpoint that expects to be paginated but doesn't require the Plug correctly.  Because of this it will always und up with the default page num and default page size even if those params are included in the query string"
        )

        {Pagination.default_page_num(), Pagination.default_page_size()}
    end
  end

  @doc """
  Take a `%Plug.Conn{}` called `conn` and return `{page_num, page_size}`
  """
  def pagination_info!(conn) do
    case pagination_info(conn) do
      {page_num, page_size} -> {page_num, page_size}
      _ -> raise Pagination.NotPaginated, conn: conn
    end
  end
end
