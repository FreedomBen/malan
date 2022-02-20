defmodule MalanWeb.SessionController do
  use MalanWeb, :controller

  require Logger

  import Malan.PaginationController, only: [require_pagination: 2, pagination_info: 1]

  alias Malan.{Accounts, Utils}
  alias Malan.Accounts.Session

  alias MalanWeb.ErrorView

  action_fallback MalanWeb.FallbackController

  plug :require_pagination,
       [table: "sessions"]
       when action in [:admin_index, :index, :index_active, :user_index_active]

  def admin_index(conn, _params) do
    {page_num, page_size} = pagination_info(conn)
    sessions = Accounts.list_sessions(page_num, page_size)
    render(conn, "index.json", sessions: sessions, page_num: page_num, page_size: page_size)
  end

  def admin_delete(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)

    with {:ok, %Session{} = session} <- Accounts.delete_session(session) do
      record_transaction(
        conn,
        true,
        session.user_id,
        "DELETE",
        "#SessionController.admin_delete/2"
      )

      render(conn, "show.json", session: session)
    else
      {:error, err} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err)

        record_transaction(
          conn,
          false,
          session.user_id,
          "DELETE",
          "#SessionController.admin_delete/2 - Session admin deletion failed: #{err_str}"
        )

        {:error, err}
    end
  end

  def index(conn, %{"user_id" => user_id}) do
    {page_num, page_size} = pagination_info(conn)
    sessions = Accounts.list_sessions(user_id, page_num, page_size)
    render(conn, "index.json", sessions: sessions, page_num: page_num, page_size: page_size)
  end

  def index_active(conn, params) do
    user_index_active(conn, Map.merge(params, %{"user_id" => conn.assigns.authed_user_id}))
  end

  def user_index_active(conn, %{"user_id" => "current"}),
    do: user_index_active(conn, %{"user_id" => conn.assigns.authed_user_id})

  def user_index_active(conn, %{"user_id" => user_id}) do
    {page_num, page_size} = pagination_info(conn)
    sessions = Accounts.list_active_sessions(user_id, page_num, page_size)
    render(conn, "index.json", sessions: sessions, page_num: page_num, page_size: page_size)
  end

  def create(conn, %{
        "session" => %{"username" => username, "password" => password} = session_opts
      }) do
    with {:ok, %Session{} = session} <-
           Accounts.create_session(username, password, put_ip_addr(session_opts, conn)) do
      record_transaction(
        %Plug.Conn{assigns: %{authed_user_id: session.user_id, authed_session_id: session.id}},
        true,
        session.user_id,
        "POST",
        "#SessionController.create/2"
      )

      conn
      |> put_status(:created)
      |> render("show.json", session: session)
    else
      # Logging of failed login attemps (aka session creation) currently happens
      # in accounts.ex
      {:error, :user_locked} ->
        conn
        |> put_status(423)
        |> put_view(ErrorView)
        |> render("423.json")

      # {:error, :not_a_user} ->
      # {:error, :unauthorized} ->
      _err ->
        conn
        |> put_status(401)
        |> put_view(ErrorView)
        |> render("401.json", invalid_credentials: true)
    end
  end

  def show(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)
    render(conn, "show.json", session: session)
  end

  def show_current(conn, %{}), do: show(conn, %{"id" => conn.assigns.authed_session_id})

  def delete(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)

    with {:ok, %Session{} = session} <- Accounts.delete_session(session) do
      record_transaction(conn, true, session.user_id, "DELETE", "#SessionController.delete/2")
      render(conn, "show.json", session: session)
    else
      {:error, err} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err)

        record_transaction(
          conn,
          false,
          session.user_id,
          "DELETE",
          "#SessionController.delete/2 - Session deletion failed: #{err_str}"
        )

        {:error, err}
    end
  end

  def delete_current(conn, %{}), do: delete(conn, %{"id" => conn.assigns.authed_session_id})

  def delete_all(conn, %{"user_id" => user_id}) do
    with {:ok, num_revoked} <- Accounts.revoke_active_sessions(user_id) do
      record_transaction(conn, true, user_id, "DELETE", "#SessionController.delete_all/2")
      render(conn, "delete_all.json", num_revoked: num_revoked)
    else
      {:error, err} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err)

        record_transaction(
          conn,
          false,
          user_id,
          "DELETE",
          "#SessionController.delete_all/2 - Session delete all active failed: #{err_str}"
        )

        {:error, err}
    end
  end

  defp record_transaction(conn, success?, who, verb, what) do
    {user_id, session_id} = authed_user_and_session(conn)
    Accounts.record_transaction(success?, user_id, session_id, who, nil, "sessions", verb, what)
    conn
  end

  defp get_ip_addr(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end

  # Get Cloudflare Real IP from request header: https://developers.cloudflare.com/fundamentals/get-started/http-request-headers
  defp get_cf_real_ip_addr(conn) do
    case get_req_header(conn, "cf-connecting_ip") do
      [real_ip] when is_binary(real_ip) -> real_ip
      _ -> nil
    end
  end

  defp put_ip_addr(session_params, conn) do
    session_params
    |> Map.put("ip_address", get_ip_addr(conn))
    |> Map.put("real_ip_address", get_cf_real_ip_addr(conn))
  end
end
