defmodule MalanWeb.UserSocket do
  use Phoenix.Socket

  require Logger

  alias Malan.Accounts
  alias Malan.Utils

  @impl true
  def connect(%{"token" => token}, socket, connect_info) when is_binary(token) and token != "" do
    case Accounts.validate_session(token, peer_ip(connect_info)) do
      {:ok, user_id, username, session_id, _ip_addr, _valid_ip_only, user_roles, expires_at,
       _tos, _pp} ->
        socket =
          socket
          |> assign(:authed_user_id, user_id)
          |> assign(:authed_username, username)
          |> assign(:authed_session_id, session_id)
          |> assign(:authed_user_roles, user_roles)
          |> assign(:auth_expires_at, expires_at)

        {:ok, socket}

      {:error, reason} ->
        Logger.info("[UserSocket.connect]: rejecting socket: #{inspect(reason)}")
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(%{assigns: %{authed_user_id: user_id}}) when is_binary(user_id),
    do: "user_socket:#{user_id}"

  def id(_socket), do: nil

  defp peer_ip(%{peer_data: %{address: address}}) when is_tuple(address),
    do: Utils.IPv4.to_s(address)

  defp peer_ip(_), do: nil
end
