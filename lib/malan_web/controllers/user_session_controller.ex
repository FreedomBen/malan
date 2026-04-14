defmodule MalanWeb.UserSessionController do
  use MalanWeb, {:controller, formats: [:html], layouts: []}

  import Malan.Utils.Phoenix.Controller, only: [remote_ip_s: 1]

  alias Malan.Accounts
  alias Malan.Accounts.Session

  def create(conn, %{"username" => username, "password" => password}) do
    remote_ip = remote_ip_s(conn)

    case Accounts.create_session(username, password, remote_ip, %{"ip_address" => remote_ip}) do
      {:ok, %Session{api_token: token}} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:api_token, token)
        |> redirect(to: ~p"/users/account")

      {:error, :user_locked} ->
        conn
        |> put_flash(:error, "This account is locked.")
        |> redirect(to: ~p"/users/login")

      {:error, :too_many_requests} ->
        conn
        |> put_flash(:error, "Too many login attempts. Please wait and try again.")
        |> redirect(to: ~p"/users/login")

      _ ->
        conn
        |> put_flash(:error, "Invalid username or password.")
        |> redirect(to: ~p"/users/login")
    end
  end

  def delete(conn, _params) do
    maybe_revoke(get_session(conn, :api_token), remote_ip_s(conn))

    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out.")
    |> redirect(to: ~p"/users/login")
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
