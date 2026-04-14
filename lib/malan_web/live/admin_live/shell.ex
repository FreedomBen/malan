defmodule MalanWeb.AdminLive.Shell do
  @moduledoc """
  Shared chrome for admin LiveViews: rail, topbar, and common display helpers.
  """

  use Phoenix.Component
  use MalanWeb, :verified_routes

  attr :current_admin, :map, required: true
  attr :active, :atom, default: :users
  attr :breadcrumbs, :list, default: []
  slot :inner_block, required: true
  slot :actions

  def admin_shell(assigns) do
    ~H"""
    <div class="admin-shell">
      <div class="admin-layout">
        <aside class="admin-rail" aria-label="Admin navigation">
          <.link navigate={~p"/admin/users"} class="admin-rail__mark" aria-label="Malan admin home">
            M
          </.link>

          <nav class="admin-rail__nav">
            <.link
              navigate={~p"/admin/users"}
              class="admin-rail__link"
              aria-current={if @active == :users, do: "page"}
              title="Users"
            >
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.4">
                <circle cx="10" cy="7" r="3.2" />
                <path d="M3.5 16.5c0-3.4 2.9-5.5 6.5-5.5s6.5 2.1 6.5 5.5" stroke-linecap="round" />
              </svg>
            </.link>
          </nav>

          <div class="admin-rail__label">Archive · Admin</div>
        </aside>

        <div class="admin-main">
          <header class="admin-topbar">
            <nav class="admin-topbar__crumbs" aria-label="Breadcrumb">
              <.link navigate={~p"/admin/users"}>Admin</.link>
              <%= for crumb <- @breadcrumbs do %>
                <span class="admin-topbar__sep" aria-hidden="true">/</span>
                <%= if crumb[:to] do %>
                  <.link navigate={crumb[:to]}>{crumb[:label]}</.link>
                <% else %>
                  <span aria-current="page">{crumb[:label]}</span>
                <% end %>
              <% end %>
            </nav>

            <div class="admin-topbar__meta">
              <span class="admin-topbar__who">
                {@current_admin.username}
              </span>
              <.link href={~p"/admin/sign_out"} method="delete" class="admin-topbar__signout">
                Sign out
              </.link>
            </div>
          </header>

          <main class="admin-content">
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>
    </div>
    """
  end

  attr :roles, :list, default: []
  attr :locked_at, :any, default: nil

  def role_pills(assigns) do
    ~H"""
    <%= cond do %>
      <% not is_nil(@locked_at) -> %>
        <span class="admin-pill admin-pill--locked">Locked</span>
      <% "admin" in (@roles || []) -> %>
        <span class="admin-pill admin-pill--admin">Admin</span>
      <% "moderator" in (@roles || []) -> %>
        <span class="admin-pill admin-pill--mod">Moderator</span>
      <% true -> %>
        <span class="admin-pill admin-pill--user">User</span>
    <% end %>
    """
  end

  attr :user, :map, required: true

  def user_avatar(assigns) do
    ~H"""
    <span class="admin-avatar" aria-hidden="true">{initial(@user)}</span>
    """
  end

  defp initial(%{first_name: fn_, last_name: ln}) when is_binary(fn_) and fn_ != "" do
    ((String.first(fn_) || "") <> (String.first(ln || "") || "·"))
    |> String.upcase()
  end

  defp initial(%{username: un}) when is_binary(un) and un != "" do
    un |> String.slice(0, 2) |> String.upcase()
  end

  defp initial(_), do: "··"

  def format_dt(nil), do: "—"

  def format_dt(%DateTime{} = dt),
    do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")

  def format_dt(%NaiveDateTime{} = dt),
    do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  def format_dt(_), do: "—"

  def short_id(nil), do: "—"
  def short_id(id) when is_binary(id), do: String.slice(id, 0, 8)
  def short_id(id), do: to_string(id)

  @doc "Formatted display name fallback chain."
  def display_name(%{display_name: d}) when is_binary(d) and d != "", do: d
  def display_name(%{first_name: f, last_name: l}) when is_binary(f) or is_binary(l) do
    [f, l] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")
  end
  def display_name(%{username: u}), do: u
  def display_name(_), do: "—"
end
