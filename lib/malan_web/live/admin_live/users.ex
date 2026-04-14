defmodule MalanWeb.AdminLive.Users do
  use MalanWeb, :live_view

  on_mount {MalanWeb.AdminAuth, :require_admin}

  alias Malan.Accounts

  @page_size 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Users",
       page: 0,
       page_size: @page_size,
       search: "",
       total: 0,
       users: []
     )
     |> load_users()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = params |> Map.get("page", "0") |> parse_int(0) |> max(0)
    search = Map.get(params, "q", "")

    {:noreply,
     socket
     |> assign(page: page, search: search)
     |> load_users()}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/users?#{[q: q, page: 0]}",
       replace: true
     )}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/users", replace: true)}
  end

  defp load_users(socket) do
    {users, total} =
      Accounts.admin_list_users(socket.assigns.page, socket.assigns.page_size,
        search: socket.assigns.search
      )

    assign(socket, users: users, total: total)
  end

  defp parse_int(val, default) do
    case Integer.parse(to_string(val)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp page_range(total, page_size, page) do
    first = if total == 0, do: 0, else: page * page_size + 1
    last = min((page + 1) * page_size, total)
    {first, last}
  end

  defp last_page(total, _page_size) when total <= 0, do: 0
  defp last_page(total, page_size) do
    div(total - 1, page_size)
  end
end
