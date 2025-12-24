defmodule MalanWeb.LogController do
  use MalanWeb, {:controller, formats: [:json], layouts: []}

  import MalanWeb.PaginationController, only: [require_pagination: 2, pagination_info: 1]

  alias Malan.Accounts

  action_fallback MalanWeb.FallbackController

  plug :is_log_user_or_admin when action in [:show]

  plug :require_pagination,
       [default_page_size: 10, max_page_size: 100]
       when action in [
              :user_index,
              :admin_index,
              :users,
              :sessions,
              :who
            ]

  # User ID of the user who made the change (token owner).
  # Must be the same as the user_id of the event for it to be returned
  def user_index(conn, %{"user_id" => "current"}) do
    user_index(conn, %{"user_id" => conn.assigns.authed_user_id})
  end

  def user_index(conn, %{"user_id" => user_id_or_username}) do
    {page_num, page_size} = pagination_info(conn)
    logs = Accounts.list_logs(user_id_or_username, page_num, page_size)

    render(conn, :index,
      code: 200,
      logs: logs,
      page_num: page_num,
      page_size: page_size
    )
  end

  # No user_id specified
  def user_index(conn, %{}) do
    user_index(conn, %{"user_id" => conn.assigns.authed_user_id})
  end

  def admin_index(conn, _params) do
    {page_num, page_size} = pagination_info(conn)
    logs = Accounts.list_logs(page_num, page_size)

    render(conn, :index,
      code: 200,
      logs: logs,
      page_num: page_num,
      page_size: page_size
    )
  end

  # User ID of the user who made the change (token owner) (Admin endpoint)
  def users(conn, %{"user_id" => user_id}) do
    {page_num, page_size} = pagination_info(conn)
    user = Accounts.get_user_by_id_or_username(user_id)
    logs = Accounts.list_logs(user, page_num, page_size)

    render(conn, :index,
      code: 200,
      logs: logs,
      page_num: page_num,
      page_size: page_size
    )
  end

  # Session ID of session who made the change
  def sessions(conn, %{"session_id" => session_id}) do
    {page_num, page_size} = pagination_info(conn)
    logs = Accounts.list_logs_by_session_id(session_id, page_num, page_size)

    render(conn, :index,
      code: 200,
      logs: logs,
      page_num: page_num,
      page_size: page_size
    )
  end

  # User ID of target/who was modified
  def who(conn, %{"user_id" => user_id}) do
    {page_num, page_size} = pagination_info(conn)
    logs = Accounts.list_logs_by_who(user_id, page_num, page_size)

    render(conn, :index,
      code: 200,
      logs: logs,
      page_num: page_num,
      page_size: page_size
    )
  end

  # Log ID
  def show(conn, %{"id" => id}) do
    log = Accounts.get_log!(id)
    render(conn, :show, log: log)
  end

  # Logs can't be created directly.
  # They are created as a side effect of other events
  # def create(conn, %{"log" => log_params}) do
  #   with {:ok, %Log{} = log} <- Accounts.create_log(log_params) do
  #     conn
  #     |> put_status(:created)
  #     |> put_resp_header("location", ~p"/api/logs/#{log}")
  #     |> render("show.json", log: log)
  #   end
  # end

  # Logs are immutable and can't be updated
  # def update(conn, %{"id" => id, "log" => log_params}) do
  #   log = Accounts.get_log!(id)

  #   with {:ok, %Log{} = log} <- Accounts.update_log(log, log_params) do
  #     render(conn, "show.json", log: log)
  #   end
  # end

  # Logs are immutable and can't be deleted
  # def delete(conn, %{"id" => id}) do
  #   log = Accounts.get_log!(id)

  #   with {:ok, %Log{}} <- Accounts.delete_log(log) do
  #     send_resp(conn, :no_content, "")
  #   end
  # end

  defp is_log_user?(conn, _opts) do
    %{user_id: log_user} = Accounts.get_log_user(conn.params["id"])
    conn.assigns.authed_user_id == log_user
  end

  defp is_log_user_or_admin(conn, opts) do
    cond do
      is_admin?(conn) -> conn
      is_log_user?(conn, opts) -> conn
      true -> halt_not_owner(conn)
    end
  end
end
