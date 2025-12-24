defmodule MalanWeb.SessionExtensionController do
  use MalanWeb, {:controller, formats: [:json], layouts: []}

  require Logger

  import MalanWeb.PaginationController, only: [require_pagination: 2, pagination_info: 1]
  import Malan.AuthController, only: [is_admin?: 1, is_owner?: 2]

  alias Malan.Accounts

  action_fallback MalanWeb.FallbackController

  plug :require_pagination, [default_page_size: 10, max_page_size: 100] when action in [:index]

  def index(conn, %{"session_id" => session_id}) do
    with :ok <- authorize(conn, session_id) do
      {page_num, page_size} = pagination_info(conn)

      conn
      |> render_index(
        Accounts.list_session_extensions(session_id, page_num, page_size),
        page_num,
        page_size
      )
    end
  end

  # Only admins can list all extensions across all sessions
  def index(conn, _params) do
    case is_admin?(conn) do
      true ->
        {page_num, page_size} = pagination_info(conn)

        conn
        |> render_index(
          Accounts.list_session_extensions(page_num, page_size),
          page_num,
          page_size
        )

      false ->
        conn
        |> put_status(401)
        |> render(MalanWeb.ErrorJSON, :"401")
    end
  end

  def show(conn, %{"id" => id}) do
    session_extension = Accounts.get_session_extension!(id)

    with :ok <- authorize(conn, session_extension.session_id) do
      render(conn, :show, code: 200, session_extension: session_extension)
    end
  end

  defp authorize(conn, session_id) do
    cond do
      is_admin?(conn) ->
        :ok

      true ->
        case Accounts.get_session(session_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> put_view(MalanWeb.ErrorJSON)
            |> render(:"404")
            |> halt()

          %{user_id: user_id} ->
            if is_owner?(conn, user_id) do
              :ok
            else
              conn
              |> put_status(:unauthorized)
              |> put_view(MalanWeb.ErrorJSON)
              |> render(:"401")
              |> halt()
            end
        end
    end
  end

  defp render_index(conn, session_extensions, page_num, page_size) do
    render(conn, :index,
      code: 200,
      session_extensions: session_extensions,
      page_num: page_num,
      page_size: page_size
    )
  end
end
