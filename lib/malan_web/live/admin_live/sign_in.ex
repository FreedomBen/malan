defmodule MalanWeb.AdminLive.SignIn do
  use MalanWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admin sign in")}
  end
end
