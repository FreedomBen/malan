defmodule MalanWeb.SessionExtensionController do
  use MalanWeb, {:controller, formats: [:json], layouts: []}

  require Logger

  import MalanWeb.PaginationController, only: [require_pagination: 2, pagination_info: 1]

  alias Malan.Accounts

  action_fallback MalanWeb.FallbackController

  plug :require_pagination, [default_page_size: 10, max_page_size: 100] when action in [:index]

  def index(conn, %{"session_id" => session_id}) do
    {page_num, page_size} = pagination_info(conn)
    conn
    |> render_index(Accounts.list_session_extensions(session_id, page_num, page_size), page_num, page_size)
  end

  def index(conn, _params) do
    {page_num, page_size} = pagination_info(conn)
    conn
    |> render_index(Accounts.list_session_extensions(page_num, page_size), page_num, page_size)
  end

  def show(conn, %{"id" => id}) do
    session_extension = Accounts.get_session_extension!(id)
    render(conn, :show, code: 200, session_extension: session_extension)
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
