defmodule MalanWeb.SessionController do
  use MalanWeb, :controller
  
  require Logger

  alias Malan.Accounts
  alias Malan.Accounts.Session

  action_fallback MalanWeb.FallbackController

  def admin_index(conn, _params) do
    sessions = Accounts.list_sessions()
    render(conn, "index.json", sessions: sessions)
  end

  def admin_delete(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)

    with {:ok, %Session{} = session} <- Accounts.delete_session(session) do
      render(conn, "show.json", session: session)
    end
  end

  def index(conn, %{"user_id" => user_id}) do
    sessions = Accounts.list_sessions(user_id)
    render(conn, "index.json", sessions: sessions)
  end

  def create(conn, %{"session" => %{"username" => username, "password" => password} = session_opts}) do
    with {:ok, %Session{} = session} <- Accounts.create_session(username, password, put_ip_addr(session_opts, conn)) do
      conn
      |> put_status(:created)
      |> render("show.json", session: session)
    else
      #{:error, :not_a_user} ->
      #{:error, :unauthorized} ->
      _err ->
        conn
        |> put_status(401)
        |> json(%{invalid_credentials: true})
    end
  end

  def show(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)
    render(conn, "show.json", session: session)
  end

  def delete(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)

    with {:ok, %Session{} = session} <- Accounts.delete_session(session) do
      render(conn, "show.json", session: session)
    end
  end

  defp get_ip_addr(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end

  defp put_ip_addr(session_params, conn) do
    session_params
    |> Map.put("ip_address", get_ip_addr(conn))
  end
end
