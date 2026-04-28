defmodule MalanWeb.AdminAuth do
  @moduledoc """
  LiveView `on_mount` hook that gates admin pages.

  Admin browser sessions reuse the regular API token flow: a successful
  sign-in stashes the token in the Plug session under `:admin_api_token`
  and the LiveView validates it here on each mount, additionally requiring
  the resolved user to carry the `"admin"` role.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias Malan.Accounts
  alias Malan.Accounts.User

  def on_mount(:require_admin, _params, session, socket) do
    case fetch_admin_user(session, socket) do
      {:ok, user} ->
        {:cont,
         socket
         |> assign(:current_admin, user)
         |> assign(:admin_api_token, Map.get(session, "admin_api_token"))}

      :error ->
        {:halt,
         socket
         |> put_flash(:error, "Admin sign-in required.")
         |> redirect(to: "/admin/sign-in")}
    end
  end

  defp fetch_admin_user(session, socket) do
    with token when is_binary(token) <- Map.get(session, "admin_api_token"),
         {:ok, user_id, _uname, _sid, _ip, _vip, roles, _exp, _tos, _pp} <-
           Accounts.validate_session(token, remote_ip(socket)),
         true <- "admin" in (roles || []),
         %User{} = user <- Accounts.get_user(user_id) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp remote_ip(socket) do
    MalanWeb.RealIp.from_connect_info(%{
      x_headers: get_connect_info(socket, :x_headers),
      peer_data: get_connect_info(socket, :peer_data)
    })
  end
end
