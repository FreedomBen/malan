defmodule MalanWeb.AdminSessionController do
  use MalanWeb, {:controller, formats: [:html], layouts: []}

  import Malan.Utils.Phoenix.Controller, only: [remote_ip_s: 1]

  alias Malan.Accounts
  alias Malan.Accounts.Session

  def create(conn, %{"username" => username, "password" => password}) do
    remote_ip = remote_ip_s(conn)

    with {:ok, %Session{api_token: token, user_id: user_id}} <-
           Accounts.create_session(username, password, remote_ip, %{"ip_address" => remote_ip}),
         {:ok, true} <- Accounts.user_is_admin?(user_id) do
      conn
      |> configure_session(renew: true)
      |> put_session(:admin_api_token, token)
      |> redirect(to: ~p"/admin/users")
    else
      {:ok, false} ->
        conn
        |> put_flash(:error, "This account is not authorized for the admin console.")
        |> redirect(to: ~p"/admin/sign-in")

      {:error, :user_locked} ->
        conn
        |> put_flash(:error, "This account is locked.")
        |> redirect(to: ~p"/admin/sign-in")

      {:error, :too_many_requests} ->
        conn
        |> put_flash(:error, "Too many sign-in attempts. Please wait and try again.")
        |> redirect(to: ~p"/admin/sign-in")

      _ ->
        conn
        |> put_flash(:error, "Invalid username or password.")
        |> redirect(to: ~p"/admin/sign-in")
    end
  end

  def delete(conn, _params) do
    maybe_revoke(get_session(conn, :admin_api_token), remote_ip_s(conn))

    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Signed out of admin.")
    |> redirect(to: ~p"/admin/sign-in")
  end

  defp maybe_revoke(nil, _ip), do: :ok

  defp maybe_revoke(token, ip) when is_binary(token) do
    case Accounts.validate_session(token, ip) do
      {:ok, _uid, _uname, session_id, _ip, _vip, _roles, _exp, _tos, _pp} ->
        case Accounts.get_session(session_id) do
          nil -> :ok
          %Session{} = s -> Accounts.revoke_session(s)
        end

      _ ->
        :ok
    end
  end
end
