defmodule MalanWeb.UserLive.Login do
  use MalanWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
