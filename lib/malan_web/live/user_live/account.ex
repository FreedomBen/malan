defmodule MalanWeb.UserLive.Account do
  use MalanWeb, :live_view

  on_mount {MalanWeb.UserAuth, :require_authed_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
