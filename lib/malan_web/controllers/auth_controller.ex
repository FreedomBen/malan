defmodule Malan.AuthController do
  import Plug.Conn

  require Logger

  alias Malan.Accounts
  alias Malan.Accounts.PrivacyPolicy
  alias Malan.Accounts.TermsOfService, as: ToS

  @doc """
  Validate that the current user is authenticated
  """
  def is_authenticated(conn, _opts) do
    Logger.debug("[is_authenticated]: Checking for authentication")
    case conn.assigns do
      %{auth_error: nil}                  -> conn
      %{auth_error: {:error, :expired}}   -> halt_status(conn, 401)
      %{auth_error: {:error, :revoked}}   -> halt_status(conn, 401)
      %{auth_error: {:error, :not_found}} -> halt_status(conn, 403)
       _                                  -> halt_status(conn, 403)
    end
  end

  @doc """
  Validate that the current user is authenticated
  """
  def has_accepted_tos(conn, _opts) do
    Logger.debug("[has_accepted_tos]:")
    case conn.assigns do
      %{authed_user_accepted_tos: true} -> conn
      _ -> halt_status(conn, 461)
    end
  end

  @doc """
  Validate that the current user is authenticated
  """
  def has_accepted_privacy_policy(conn, _opts) do
    Logger.debug("[has_accepted_privacy_policy]:")
    case conn.assigns do
      %{authed_user_accepted_pp: true} -> conn
      _ -> halt_status(conn, 462)
    end
  end

  @doc """
  Validate that the current user is an admin
  """
  def is_admin(conn, _opts) do
    Logger.debug("[is_admin]:")
    case conn.assigns do
      %{authed_user_is_admin: true} -> conn
      %{auth_error: nil} -> halt_status(conn, 401)
       _                 -> halt_status(conn, 403)
    end
  end

  @doc """
  Validate that the current user is a moderator or an admin
  """
  def is_moderator(conn, _opts) do
    Logger.debug("[is_moderator]:")
    case conn.assigns do
      %{authed_user_is_admin: true} -> conn
      %{authed_user_is_moderator: true} -> conn
      %{auth_error: nil} -> halt_status(conn, 401)
       _                 -> halt_status(conn, 403)
    end
  end

  @doc """
  validate_token/2 is a plug function that will:

  1.  Take in a conn
  2.  Extract the API token from the request headers
  3.  Lookup the Session in the DB
  4.  Determine if it is valid
  5.  If valid, add user_id and roles to the conn.assigns
  """
  def validate_token(conn, _opts) do
    with {:ok, api_token} <- retrieve_token(conn),
         {:ok, user_id, user_roles, expires_at, tos, pp} <- Accounts.validate_session(api_token),
         {:ok, accepted_tos} <- accepted_latest_tos?(tos),
         {:ok, accepted_pp} <- accepted_latest_pp?(pp),
         {:ok, is_admin} <- Accounts.user_is_admin?(user_roles),
         {:ok, is_moderator}  <- Accounts.user_is_moderator?(user_roles)
    do
      conn
      |> assign(:auth_error, nil)
      |> assign(:authed_user_id, user_id)
      |> assign(:auth_expires_at, expires_at)
      |> assign(:authed_user_roles, user_roles)
      |> assign(:authed_user_is_admin, is_admin)
      |> assign(:authed_user_accepted_pp, accepted_pp)
      |> assign(:authed_user_accepted_tos, accepted_tos)
      |> assign(:authed_user_is_moderator, is_moderator)
    else
      #{:error, :no_token} ->
      #{:error, :not_found} ->
      #{:error, :malformed} ->
      {:error, err} ->
        Logger.info("[validate_token]: API token error: #{err}")
        conn
        |> assign(:auth_error, err)
        |> assign(:authed_user_id, nil)
        |> assign(:auth_expires_at, nil)
        |> assign(:authed_user_roles, [])
        |> assign(:authed_user_is_admin, false)
        |> assign(:authed_user_accepted_pp, false)
        |> assign(:authed_user_accepted_tos, false)
        |> assign(:authed_user_is_moderator, false)
    end
  end

  def halt_not_owner(conn), do: halt_status(conn, 401)

  def halt_status(conn, status) do
    Logger.debug("[halt_status]: status: #{status}")
    conn
    |> put_status(status)
    |> Phoenix.Controller.put_view(MalanWeb.ErrorView)
    |> Phoenix.Controller.render("#{status}.json")
    |> halt()
  end

  def is_admin?(conn), do: !!conn.assigns.authed_user_is_admin
  def is_moderator?(conn), do: !!conn.assigns.authed_user_is_moderator
  def is_moderator_or_admin?(conn), do: !!(is_moderator?(conn) || is_admin?(conn))
  def is_admin_or_moderator?(conn), do: is_moderator_or_admin?(conn)
  def is_owner?(conn), do: is_owner?(conn, conn.params["user_id"])
  def is_owner?(conn, user_id), do: conn.assigns.authed_user_id == user_id

  def is_not_admin?(conn), do: !is_admin?(conn)
  def is_not_moderator?(conn), do: !is_moderator?(conn)
  def is_not_moderator_or_admin?(conn), do: !is_admin?(conn) && !is_moderator?(conn)
  def is_not_admin_or_moderator?(conn), do: is_not_moderator_or_admin?(conn)
  def is_not_owner?(conn), do: !is_owner?(conn)
  def is_not_owner?(conn, user_id), do: !is_owner?(conn, user_id)

  def is_owner_or_admin(conn, _opts) do
    cond do
      is_owner?(conn) || is_admin?(conn) -> conn
      true -> halt_not_owner(conn)
    end
  end

  def is_owner_or_moderator(conn, _opts) do
    cond do
      is_owner?(conn) || is_moderator?(conn) -> conn
      true -> halt_not_owner(conn)
    end
  end

  def is_owner(conn, user_id) when is_binary(user_id) do
    cond do
      is_owner?(conn, user_id) -> conn
      true -> halt_not_owner(conn)
    end
  end

  def is_owner(conn, _opts) do
    cond do
      is_owner?(conn) -> conn
      true -> halt_not_owner(conn)
    end
  end

  defp parse_authorization(conn), do:
    Enum.find(conn.req_headers, fn ({k, _v}) -> k == "authorization" end)

  defp retrieve_token(conn) do
    case parse_authorization(conn) do
      {"authorization", auth_string} -> extract_token(auth_string)
      _                              -> {:error, :no_token}
    end
  end

  defp extract_token(auth_string) do
    case String.split(auth_string, " ") do
      [_, api_token] -> {:ok, api_token}
       _             -> {:error, :malformed}
    end
  end

  def accepted_latest_tos?(tos) do
    {:ok, tos == ToS.current_version()}
  end

  def accepted_latest_pp?(pp) do
    {:ok, pp == PrivacyPolicy.current_version()}
  end
end
