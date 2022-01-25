defmodule MalanWeb.UserController do
  use MalanWeb, :controller

  require Logger

  import Malan.PaginationController, only: [require_pagination: 2, pagination_info: 1]

  alias Malan.Accounts
  alias Malan.Accounts.User

  action_fallback MalanWeb.FallbackController

  plug :require_pagination, [table: "users"] when action in [:index]
  plug :is_self_or_admin
       when action not in [
              :index,
              :create,
              :whoami,
              :me,
              :current,
              :admin_reset_password,
              :admin_reset_password_token
            ]

  def index(conn, _params) do
    {page_num, page_size} = pagination_info(conn)
    users = Accounts.list_users(page_num, page_size)
    render(conn, "index.json", users: users, page_num: page_num, page_size: page_size)
  end

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{id: id, username: username} = user} <- Accounts.register_user(user_params) do
      conn
      |> record_transaction(id, username, "POST", "#UserController.create/2")
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end

  # Deprecated in favor of "current'
  def me(conn, _params), do: show(conn, %{"id" => conn.assigns.authed_user_id})
  def current(conn, _params), do: show(conn, %{"id" => conn.assigns.authed_user_id})

  def show(conn, %{"id" => id, "abbr" => _}) do
    user = Accounts.get_user_by_id_or_username(id)
    render_user(conn, user)
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user_full_by_id_or_username(id)
    render_user(conn, user)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user_full_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      with {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
        record_transaction(conn, user.id, user.username, "PUT", "#UserController.update/2")
        render(conn, "show.json", user: user)
      end
    end
  end

  def admin_update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user_full_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      with {:ok, %User{} = user} <- Accounts.admin_update_user(user, user_params) do
        record_transaction(conn, user.id, user.username, "PUT", "#UserController.admin_update/2")
        render(conn, "show.json", user: user)
      end
    end
  end

  def lock(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username!(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      with {:ok, %User{}} <- Accounts.lock_user(user, conn.assigns.authed_user_id) do
        record_transaction(conn, user.id, user.username, "PUT", "#UserController.lock/2")
        send_resp(conn, :no_content, "")
      end
    end
  end

  def unlock(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username!(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      with {:ok, %User{}} <- Accounts.unlock_user(user) do
        record_transaction(conn, user.id, user.username, "PUT", "#UserController.unlock/2")
        send_resp(conn, :no_content, "")
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username!(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      with {:ok, %User{}} <- Accounts.delete_user(user) do
        record_transaction(conn, user.id, user.username, "DELETE", "#UserController.delete/2")
        send_resp(conn, :no_content, "")
      end
    end
  end

  def admin_reset_password(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      with {:ok, %User{} = user} <- Accounts.generate_password_reset(user) do
        record_transaction(
          conn,
          user.id,
          user.username,
          "PUT",
          "#UserController.admin_reset_password/2"
        )

        render_password_reset(conn, user)
      end
    end
  end

  def whoami(conn, _params) do
    case conn_to_session_info(conn) do
      {:ok, user_id, _username, session_id, user_roles, expires_at, tos, pp} ->
        render_whoami(conn, user_id, session_id, user_roles, expires_at, tos, pp)

      # {:error, :revoked}
      # {:error, :expired}
      # {:error, :not_found}
      {:error, _} ->
        send_resp(conn, :not_found, "")
    end
  end

  def admin_reset_password_token_user(conn, %{
        "id" => id,
        "token" => token,
        "new_password" => new_password
      }),
      do:
        admin_reset_password_token_p(
          conn,
          Accounts.get_user_by_id_or_username(id),
          token,
          new_password
        )

  def admin_reset_password_token(conn, %{"token" => token, "new_password" => new_password}),
    do:
      admin_reset_password_token_p(
        conn,
        Accounts.get_user_by_password_reset_token(token),
        token,
        new_password
      )

  defp admin_reset_password_token_p(conn, nil, _token, _new_password),
    do: render_user(conn, nil)

  defp admin_reset_password_token_p(conn, %User{} = user, token, new_password) do
    with {:ok, %User{} = _user} <- Accounts.reset_password_with_token(user, token, new_password) do
      record_transaction(
        conn,
        user.id,
        user.username,
        "PUT",
        "#UserController.admin_reset_password_token/3"
      )

      conn
      |> put_status(200)
      |> json(%{ok: true})
    else
      {:error, :missing_password_reset_token} ->
        conn
        |> put_status(401)
        |> json(%{
          ok: false,
          err: :missing_password_reset_token,
          msg: "No password reset token has been issued"
        })

      {:error, :invalid_password_reset_token} ->
        conn
        |> put_status(401)
        |> json(%{
          ok: false,
          err: :invalid_password_reset_token,
          msg: "Password reset token in invalid"
        })

      {:error, :expired_password_reset_token} ->
        conn
        |> put_status(401)
        |> json(%{
          ok: false,
          err: :expired_password_reset_token,
          msg: "Password reset token is expired"
        })
    end
  end

  defp record_transaction(conn, who, who_username, verb, what) do
    {user_id, session_id} = authed_user_and_session(conn)
    Accounts.record_transaction(user_id, session_id, who, who_username, "users", verb, what)
    conn
  end

  defp render_whoami(conn, user_id, session_id, user_roles, expires_at, tos, pp) do
    render(
      conn,
      "whoami.json",
      user_id: user_id,
      session_id: session_id,
      user_roles: user_roles,
      expires_at: expires_at,
      tos: tos,
      pp: pp
    )
  end

  defp render_user(conn, user) do
    if is_nil(user) do
      conn
      |> put_status(:not_found)
      |> put_view(MalanWeb.ErrorView)
      |> render(:"404")
    else
      render(conn, "show.json", user: user)
    end
  end

  defp render_password_reset(conn, user) do
    render(
      conn,
      "password_reset.json",
      password_reset_token: user.password_reset_token,
      password_reset_token_expires_at: user.password_reset_token_expires_at
    )
  end

  defp is_self_or_admin(conn, _opts) do
    if is_self?(conn) || is_admin?(conn) do
      conn
    else
      halt_not_owner(conn)
    end
  end

  defp is_self?(conn) do
    conn.assigns.authed_user_id == conn.params["id"] ||
      conn.assigns.authed_username == conn.params["id"]
  end

  defp conn_to_session_info(conn) do
    with {:ok, api_token} <- retrieve_token(conn),
         {:ok, user_id, session_id, user_roles, expires_at, tos, pp} <-
           Accounts.validate_session(api_token) do
      {:ok, user_id, session_id, user_roles, expires_at, tos, pp}
    end
  end
end
