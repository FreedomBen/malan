defmodule MalanWeb.UserController do
  use MalanWeb, :controller

  alias Malan.Accounts
  alias Malan.Accounts.User
  alias Malan.AuthController

  action_fallback MalanWeb.FallbackController

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
    users = Accounts.list_users()
    render(conn, "index.json", users: users)
  end

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.register_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end

  # Deprecated in favor of "current'
  def me(conn, _params),      do: show(conn, %{"id" => conn.assigns.authed_user_id})
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
        render(conn, "show.json", user: user)
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username!(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      with {:ok, %User{}} <- Accounts.delete_user(user) do
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
        render_password_reset(conn, user)
      end
    end
  end

  def whoami(conn, _params) do
    case conn_to_session_info(conn) do
      {:ok, user_id, username, session_id, user_roles, expires_at, tos, pp} ->
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

  defp admin_reset_password_token_p(conn, nil, token, new_password),
    do: render_user(conn, nil)

  defp admin_reset_password_token_p(conn, %User{} = user, token, new_password) do
    with {:ok, %User{} = _user} <- Accounts.reset_password_with_token(user, token, new_password) do
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

  defp is_self(conn, _opts) do
    if is_self?(conn) do
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
