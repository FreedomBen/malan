defmodule Malan.PaginationController do
  import Plug.Conn
  import Malan.Utils.Phoenix.Controller

  import Ecto.Changeset, only: [apply_action: 2]

  require Logger

  alias Malan.Accounts
  alias Malan.Pagination
  alias Malan.Accounts.PrivacyPolicy
  alias Malan.Accounts.TermsOfService, as: ToS

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
  """
  def validate_pagination(conn, _opts) do
    with {:ok, page_num, page_size} <- extract_page_info(conn) do
      conn
      |> assign(:pagination_error, nil)
      |> assign(:pagination_page_num, page_num)
      |> assign(:pagination_page_size, page_size)
    else
      # {:error, :page_num} ->
      # {:error, :page_size} ->
      {:error, err} ->
        Logger.info("[validate_pagination]: pagination error: #{err}")

        conn
        |> assign(:pagination_error, err)
        |> assign(:pagination_page_num, nil)
        |> assign(:pagination_page_size, nil)
    end
  end

  def require_pagination(conn, opts) do
    conn
    |> validate_pagination(opts)
    |> is_paginated(opts)
  end

  def extract_page_info(%Plug.Conn{params: params} = conn) do
    extract_page_info(params)
  end

  def extract_page_info(params) do
    case Pagination.changeset(%Pagination{}, params) |> apply_action(:update) do
      {:ok, %Pagination{} = p} -> {:ok, p.page_num, p.page_size}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
