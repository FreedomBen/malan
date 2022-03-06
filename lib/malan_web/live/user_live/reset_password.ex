defmodule MalanWeb.UserLive.ResetPassword do
  use MalanWeb, :live_view

  # Wires up socket assigns and after invokes handle_params/3
  @impl true
  def mount(_params, _session, socket) do
    #{:ok, assign(socket, :pages, list_pages())}
    #{:ok, assign(socket, :page, %{id: "TheID", title: "TheTitle", page: "ThePage"})}
    {:ok, socket}
  end

  # Handle URI and query params
  @impl true
  def handle_params(_params, _url, socket) do
    #{:noreply, apply_action(socket, socket.assigns.live_action, params)}
    {:noreply, socket}
  end

  # # Render HTML to client
  # @impl true
  # def render(assigns) do
  #   Phoenix.View.render(MalanWeb.PageView, "reset_password.html", assigns)
  #   Phoenix.LiveView.render(...)
  #   Phoenix.LiveView.live_render(...)
  # end

  defp apply_action(socket, :reset_password, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Page")
    |> assign(:page, Pages.get_page!(id))
  end

#  defp apply_action(socket, :new, _params) do
#    socket
#    |> assign(:page_title, "New Page")
#    |> assign(:page, %Page{})
#  end
#
#  defp apply_action(socket, :index, _params) do
#    socket
#    |> assign(:page_title, "Listing Pages")
#    |> assign(:page, nil)
#  end
#
#  @impl true
#  def handle_event("delete", %{"id" => id}, socket) do
#    page = Pages.get_page!(id)
#    {:ok, _} = Pages.delete_page(page)
#
#    {:noreply, assign(socket, :pages, list_pages())}
#  end
#
#  defp list_pages do
#    Pages.list_pages()
#  end
end
