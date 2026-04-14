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
       has_next: false,
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
    {users, has_next} =
      Accounts.admin_list_users(socket.assigns.page, socket.assigns.page_size,
        search: socket.assigns.search
      )

    assign(socket, users: users, has_next: has_next)
  end

  defp parse_int(val, default) do
    case Integer.parse(to_string(val)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp page_range(users, page_size, page) do
    case length(users) do
      0 -> {0, 0}
      n -> {page * page_size + 1, page * page_size + n}
    end
  end
end
