defmodule MalanWeb.UserLive.ResetPasswordToken do
  use MalanWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    #{:ok, assign(socket, :pages, list_pages())}
    #{:ok, socket}
    {:ok, assign(socket, :page, %{id: "TheID", title: "TheTitle", page: "ThePage"})}
  end

  #@impl true
  #def render(assigns) do
  #  Phoenix.View.render(MalanWeb.PageView, "page.html", assigns)
  #  Phoenix.LiveView.render(...)
  #  Phoenix.LiveView.live_render(...)
  #end

  @impl true
  def handle_params(_params, _url, socket) do
    #{:noreply, apply_action(socket, socket.assigns.live_action, params)}
    {:noreply, socket}
  end

#  defp apply_action(socket, :edit, %{"id" => id}) do
#    socket
#    |> assign(:page_title, "Edit Page")
#    |> assign(:page, Pages.get_page!(id))
#  end
#
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
