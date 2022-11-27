defmodule MalanWeb.UserController do
  use MalanWeb, :controller

  require Logger

  import Malan.PaginationController, only: [require_pagination: 2, pagination_info: 1]
  import Malan.Utils.Phoenix.Controller, only: [remote_ip_s: 1]

  alias Malan.Accounts
  alias Malan.Accounts.User
  alias Malan.Mailer
  alias Malan.Utils

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
              :admin_reset_password_token,
              :reset_password,
              :reset_password_token_user,
              :reset_password_token
            ]

  def index(conn, _params) do
    {page_num, page_size} = pagination_info(conn)
    users = Accounts.list_users(page_num, page_size)
    render(conn, "index.json", code: 200, users: users, page_num: page_num, page_size: page_size)
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.registration_changeset(%User{}, user_params)

    with {:ok, %User{id: id, username: username} = user} <- Accounts.register_user(user_params) do
      # UserNotifier.email_welcome_confirm(user)
      # |> Mailer.deliver()
      conn
      |> record_log(true, id, username, "POST", "#UserController.create/2", changeset)
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", code: 201, user: user)
    else
      {:error, err} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err)

        record_log(
          conn,
          false,
          nil,
          user_params["username"],
          "POST",
          "#UserController.create/2 - User account creation failed: #{err_str}",
          changeset
        )

        {:error, err}
    end
  end

  # "me" is deprecated in favor of "current'
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
      changeset = User.update_changeset(user, user_params)

      with {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
        record_log(
          conn,
          true,
          user.id,
          user.username,
          "PUT",
          "#UserController.update/2",
          changeset
        )

        render(conn, "show.json", code: 200, user: user)
      else
        {:error, err} ->
          err_str = Utils.Ecto.Changeset.errors_to_str(err)

          record_log(
            conn,
            false,
            user.id,
            user.username,
            "PUT",
            "#UserController.update/2 - User update failed: #{err_str}",
            changeset
          )

          {:error, err}
      end
    end
  end

  def admin_update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user_full_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      changeset = User.admin_changeset(user, user_params)

      with {:ok, %User{} = user} <- Accounts.admin_update_user(user, user_params) do
        record_log(
          conn,
          true,
          user.id,
          user.username,
          "PUT",
          "#UserController.admin_update/2",
          changeset
        )

        render(conn, "show.json", code: 200, user: user)
      else
        {:error, err} ->
          err_str = Utils.Ecto.Changeset.errors_to_str(err)

          record_log(
            conn,
            false,
            user.id,
            user.username,
            "PUT",
            "#UserController.admin_update/2 - User update by admin failed: #{err_str}",
            changeset
          )

          {:error, err}
      end
    end
  end

  def lock(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      changeset = User.lock_changeset(user, conn.assigns.authed_user_id)

      with {:ok, %User{} = user} <- Accounts.lock_user(user, conn.assigns.authed_user_id) do
        record_log(
          conn,
          true,
          user.id,
          user.username,
          "PUT",
          "#UserController.lock/2",
          changeset
        )

        render(conn, "show.json", code: 200, user: user)
      else
        {:error, %Ecto.Changeset{} = cs} ->
          err_str = Utils.Ecto.Changeset.errors_to_str(cs)

          record_log(
            conn,
            false,
            user.id,
            user.username,
            "PUT",
            "#UserController.lock/2 - User lock failed: #{err_str}",
            changeset
          )

          {:error, cs}

        {:error, err} ->
          record_log(
            conn,
            false,
            user.id,
            user.username,
            "PUT",
            "#UserController.lock/2 - User lock failed: #{Kernel.inspect(err)}",
            changeset
          )

          {:error, err}
      end
    end
  end

  def unlock(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      changeset = User.unlock_changeset(user)

      with {:ok, %User{} = user} <- Accounts.unlock_user(user) do
        record_log(
          conn,
          true,
          user.id,
          user.username,
          "PUT",
          "#UserController.unlock/2",
          changeset
        )

        render(conn, "show.json", code: 200, user: user)
      else
        {:error, err} ->
          err_str = Utils.Ecto.Changeset.errors_to_str(err)

          record_log(
            conn,
            false,
            user.id,
            user.username,
            "PUT",
            "#UserController.unlock/2 - User unlock failed: #{err_str}",
            changeset
          )

          {:error, err}
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      changeset = User.delete_changeset(user)

      with {:ok, %User{}} <- Accounts.delete_user(user) do
        record_log(
          conn,
          true,
          user.id,
          user.username,
          "DELETE",
          "#UserController.delete/2",
          changeset
        )

        send_resp(conn, :no_content, "")
      else
        {:error, err} ->
          err_str = Utils.Ecto.Changeset.errors_to_str(err)

          record_log(
            conn,
            false,
            user.id,
            user.username,
            "DELETE",
            "#UserController.delete/2 - User delete failed: #{err_str}",
            changeset
          )

          {:error, err}
      end
    end
  end

  def whoami(conn, _params) do
    case conn_to_session_info(conn) do
      {:ok, user_id, _username, session_id, ip_addr, valid_only_ip, user_roles, expires_at, tos,
       pp} ->
        render_whoami(
          conn,
          user_id,
          session_id,
          ip_addr,
          valid_only_ip,
          user_roles,
          expires_at,
          tos,
          pp
        )

      {:error, err} ->
        render_token_error(conn, err)
    end
  end

  def reset_password(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      # Note:  This is very similar to the actual changeset, but not the
      # exact same.  Slightly different utc times, and different api_token and
      # api_token_hash.  Might be misleadings and we should consider just
      # setting the log changeset to nil

      changeset = User.password_reset_create_changeset(user)

      with {:ok, %User{} = user} <- Accounts.generate_password_reset(user),
           {:ok, term} <- Mailer.send_password_reset_email(user) do
        record_log(
          conn,
          true,
          user.id,
          user.username,
          "POST",
          "#UserController.reset_password/2 - term: '#{Utils.to_string(term)}",
          changeset
        )

        conn
        |> put_status(200)
        |> json(%{ok: true, code: 200})
      else
        {:error, {401, _} = error} ->
          record_log_password_reset_email_fail(
            conn,
            user,
            "Mail provider authentication seems to have failed: #{Utils.to_string(error)}",
            changeset
          )

          render(conn, "500.json")

          {:error, :too_many_requests}

          record_log_password_reset_email_fail(
            conn,
            user,
            "Rate limit exceeded for user #{user.username}",
            changeset
          )

          render(conn, "429.json")

        {:error, err_cs} ->
          err_str = Utils.Ecto.Changeset.errors_to_str(err_cs)
          record_log_password_reset_email_fail(conn, user, err_str, err_cs)
          {:error, err_cs}
      end
    end
  end

  def reset_password_token_user(conn, %{
        "id" => id,
        "token" => token,
        "new_password" => new_password
      }) do
    user = Accounts.get_user_by_id_or_username(id)
    reset_password_token_p(conn, user, token, new_password)
  end

  def reset_password_token(conn, %{"token" => token, "new_password" => new_password}) do
    user = Accounts.get_user_by_password_reset_token(token)
    reset_password_token_p(conn, user, token, new_password)
  end

  def admin_reset_password(conn, %{"id" => id}) do
    user = Accounts.get_user_by_id_or_username(id)

    if is_nil(user) do
      render_user(conn, user)
    else
      # Note:  This is very similar to the actual changeset, but not the
      # exact same.  Slightly different utc times, and different api_token and
      # api_token_hash.  Might be misleadings and we should consider just
      # setting the log changeset to nil
      changeset = User.password_reset_create_changeset(user)

      # As an admin endpoint we don't rate limit this specifically (although
      # there is a general rate limit)
      with {:ok, %User{} = user} <- Accounts.generate_password_reset(user, :no_rate_limit) do
        record_log(
          conn,
          true,
          user.id,
          user.username,
          "POST",
          "#UserController.admin_reset_password/2",
          changeset
        )

        render_admin_password_reset(conn, user)
      else
        {:error, err_cs} ->
          err_str = Utils.Ecto.Changeset.errors_to_str(err_cs)

          record_log(
            conn,
            false,
            user.id,
            user.username,
            "POST",
            "#UserController.admin_reset_password/2 - User admin reset password failed: #{err_str}",
            err_cs
          )

          {:error, err_cs}
      end
    end
  end

  def admin_reset_password_token_user(conn, %{
        "id" => id,
        "token" => token,
        "new_password" => new_password
      }),
      do:
        reset_password_token_p(
          conn,
          Accounts.get_user_by_id_or_username(id),
          token,
          new_password
        )

  def admin_reset_password_token(conn, %{"token" => token, "new_password" => new_password}),
    do:
      reset_password_token_p(
        conn,
        Accounts.get_user_by_password_reset_token(token),
        token,
        new_password
      )

  defp reset_password_token_p(conn, nil, _token, _new_password),
    do: render_user(conn, nil)

  defp reset_password_token_p(conn, %User{} = user, token, new_password) do
    log_changeset = User.update_changeset(user, %{"password" => Utils.mask_str(new_password)})

    with {:ok, %User{} = _user} <- Accounts.reset_password_with_token(user, token, new_password) do
      record_log(
        conn,
        true,
        user.id,
        user.username,
        "PUT",
        "#UserController.admin_reset_password_token/3",
        log_changeset
      )

      conn
      |> put_status(200)
      |> json(%{ok: true, code: 200})
    else
      {:error, :missing_password_reset_token = err} ->
        conn
        |> record_log_admin_reset_password_token_fail(user, err, log_changeset)
        |> put_status(401)
        |> json(%{
          ok: false,
          code: 401,
          err: err,
          msg: "No password reset token has been issued"
        })

      {:error, :invalid_password_reset_token = err} ->
        conn
        |> record_log_admin_reset_password_token_fail(user, err, log_changeset)
        |> put_status(401)
        |> json(%{
          ok: false,
          code: 401,
          err: err,
          msg: "Password reset token in invalid"
        })

      {:error, :expired_password_reset_token = err} ->
        conn
        |> record_log_admin_reset_password_token_fail(user, err, log_changeset)
        |> put_status(401)
        |> json(%{
          ok: false,
          code: 401,
          err: err,
          msg: "Password reset token is expired"
        })
    end
  end

  defp record_log_admin_reset_password_token_fail(conn, user, err, log_changeset) do
    record_log(
      conn,
      false,
      user.id,
      user.username,
      "PUT",
      "#UserController.admin_reset_password_token/3 - Err: #{err}",
      log_changeset
    )

    conn
  end

  defp record_log(conn, success?, who, who_username, verb, what, log_changeset) do
    {user_id, session_id} = authed_user_and_session(conn)

    Accounts.record_log(
      success?,
      user_id,
      session_id,
      who,
      who_username,
      "users",
      verb,
      what,
      remote_ip_s(conn),
      log_changeset
    )

    conn
  end

  defp record_log_password_reset_email_fail(conn, user, err_str, log_changeset) do
    record_log(
      conn,
      false,
      user.id,
      user.username,
      "POST",
      "#UserController.reset_password/2 - User reset password failed: #{err_str}",
      log_changeset
    )
  end

  defp render_whoami(
         conn,
         user_id,
         session_id,
         ip_addr,
         valid_only_ip,
         user_roles,
         expires_at,
         tos,
         pp
       ) do
    render(
      conn,
      "whoami.json",
      code: 200,
      user_id: user_id,
      session_id: session_id,
      user_roles: user_roles,
      ip_address: ip_addr,
      valid_only_for_ip: valid_only_ip,
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
      render(conn, "show.json", code: 200, user: user)
    end
  end

  defp render_admin_password_reset(conn, user) do
    render(
      conn,
      "password_reset.json",
      code: 200,
      password_reset_token: user.password_reset_token,
      password_reset_token_expires_at: user.password_reset_token_expires_at
    )
  end

  defp render_token_error(conn, :expired) do
    render_token_error(conn, 403, %{token_expired: true})
  end

  defp render_token_error(conn, :revoked) do
    render_token_error(conn, 403, %{token_revoked: true})
  end

  defp render_token_error(conn, :not_found) do
    render_token_error(conn, 404)
  end

  defp render_token_error(conn, error) when is_atom(error) do
    render_token_error(conn, 403)
  end

  defp render_token_error(conn, status, details \\ %{}) do
    conn
    |> put_status(status)
    |> put_view(MalanWeb.ErrorView)
    |> render("#{status}.json", details)
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
         {:ok, user_id, session_id, ip_addr, valid_only_ip, user_roles, expires_at, tos, pp} <-
           Accounts.validate_session(api_token, Utils.IPv4.to_s(conn)) do
      {:ok, user_id, session_id, ip_addr, valid_only_ip, user_roles, expires_at, tos, pp}
    end
  end
end
