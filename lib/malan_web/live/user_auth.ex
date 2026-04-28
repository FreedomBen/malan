defmodule MalanWeb.UserAuth do
  @moduledoc """
  LiveView authentication helpers for session-cookie-based browser flows.

  The API is token-authenticated via `Authorization: Bearer`; for LiveViews
  we stash the same API token in the Plug session cookie under `:api_token`
  and validate it here on each mount.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias Malan.Accounts
  alias Malan.Accounts.User

  @doc """
  `on_mount` hook. Use in `live_session`:

      live_session :authed, on_mount: {MalanWeb.UserAuth, :require_authed_user} do
        live "/users/account", UserLive.Account
      end
  """
  def on_mount(:require_authed_user, _params, session, socket) do
    case fetch_current_user(session, socket) do
      {:ok, user} ->
        {:cont, assign(socket, :current_user, user)}

      :error ->
        {:halt, redirect(socket, to: "/users/login")}
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    case fetch_current_user(session, socket) do
      {:ok, user} -> {:cont, assign(socket, :current_user, user)}
      :error -> {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp fetch_current_user(session, socket) do
    with token when is_binary(token) <- Map.get(session, "api_token"),
         {:ok, user_id, _username, _sid, _ip, _vip, _roles, _exp, _tos, _pp} <-
           Accounts.validate_session(token, remote_ip(socket)),
         %User{} = user <- Accounts.get_user(user_id) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc """
  Returns the client IP for a LiveView socket as a printable string.

  Prefers the Cloudflare-reported IP from `cf-connecting-ip` and falls
  back to the TCP peer. Returns `"0.0.0.0"` when neither is available
  (e.g. server-internal mounts). Delegates to `MalanWeb.RealIp` so the
  HTTP and LiveView paths share one trust model.
  """
  def remote_ip(socket) do
    MalanWeb.RealIp.from_connect_info(%{
      x_headers: get_connect_info(socket, :x_headers),
      peer_data: get_connect_info(socket, :peer_data)
    })
  end
end
