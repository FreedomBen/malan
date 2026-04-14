defmodule MalanWeb.AdminLive.Shell do
  @moduledoc """
  Shared chrome for admin LiveViews: Tailwind Plus dashboard shell
  (static desktop sidebar + mobile dialog drawer + sticky top bar).
  """

  use Phoenix.Component
  use MalanWeb, :verified_routes

  attr :current_admin, :map, required: true
  attr :active, :atom, default: :users
  slot :inner_block, required: true

  def admin_shell(assigns) do
    ~H"""
    <!-- Mobile sidebar (Tailwind Plus el-dialog) -->
    <el-dialog>
      <dialog id="admin-sidebar" class="backdrop:bg-transparent lg:hidden">
        <el-dialog-backdrop class="fixed inset-0 bg-gray-900/80 transition-opacity duration-300 ease-linear data-closed:opacity-0">
        </el-dialog-backdrop>

        <div tabindex="0" class="fixed inset-0 flex focus:outline-none">
          <el-dialog-panel class="group/dialog-panel relative mr-16 flex w-full max-w-xs flex-1 transform transition duration-300 ease-in-out data-closed:-translate-x-full">
            <div class="absolute top-0 left-full flex w-16 justify-center pt-5 duration-300 ease-in-out group-data-closed/dialog-panel:opacity-0">
              <button type="button" command="close" commandfor="admin-sidebar" class="-m-2.5 p-2.5">
                <span class="sr-only">Close sidebar</span>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true" class="size-6 text-white">
                  <path d="M6 18 18 6M6 6l12 12" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </button>
            </div>

            <.sidebar_panel active={@active} current_admin={@current_admin} />
          </el-dialog-panel>
        </div>
      </dialog>
    </el-dialog>

    <!-- Static desktop sidebar -->
    <div class="hidden bg-gray-900 lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-72 lg:flex-col">
      <.sidebar_panel active={@active} current_admin={@current_admin} />
    </div>

    <div class="lg:pl-72">
      <div class="sticky top-0 z-40 flex h-16 shrink-0 items-center gap-x-4 border-b border-gray-200 bg-white px-4 shadow-xs sm:gap-x-6 sm:px-6 lg:px-8 dark:border-white/10 dark:bg-gray-900 dark:shadow-none">
        <button
          type="button"
          command="show-modal"
          commandfor="admin-sidebar"
          class="-m-2.5 p-2.5 text-gray-700 hover:text-gray-900 lg:hidden dark:text-gray-400 dark:hover:text-white"
        >
          <span class="sr-only">Open sidebar</span>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true" class="size-6">
            <path d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </button>

        <div aria-hidden="true" class="h-6 w-px bg-gray-200 lg:hidden dark:bg-white/10"></div>

        <div class="flex flex-1 gap-x-4 self-stretch lg:gap-x-6">
          <div class="flex flex-1"></div>

          <div class="flex items-center gap-x-4 lg:gap-x-6">
            <div aria-hidden="true" class="hidden lg:block lg:h-6 lg:w-px lg:bg-gray-200 dark:lg:bg-white/10"></div>

            <el-dropdown class="relative">
              <button class="relative flex items-center" type="button">
                <span class="absolute -inset-1.5"></span>
                <span class="sr-only">Open user menu</span>
                <span class="flex size-8 items-center justify-center rounded-full bg-indigo-600 text-xs font-semibold text-white uppercase">
                  {initials(@current_admin)}
                </span>
                <span class="hidden lg:flex lg:items-center">
                  <span aria-hidden="true" class="ml-4 text-sm/6 font-semibold text-gray-900 dark:text-white">
                    {@current_admin.username}
                  </span>
                  <svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true" class="ml-2 size-5 text-gray-400 dark:text-gray-500">
                    <path fill-rule="evenodd" clip-rule="evenodd" d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z" />
                  </svg>
                </span>
              </button>
              <el-menu anchor="bottom end" popover class="w-44 origin-top-right rounded-md bg-white py-2 shadow-lg outline-1 outline-gray-900/5 transition transition-discrete [--anchor-gap:--spacing(2.5)] data-closed:scale-95 data-closed:transform data-closed:opacity-0 data-enter:duration-100 data-enter:ease-out data-leave:duration-75 data-leave:ease-in dark:bg-gray-800 dark:shadow-none dark:-outline-offset-1 dark:outline-white/10">
                <.link
                  navigate={~p"/admin/users/#{@current_admin.id}"}
                  class="block px-3 py-1 text-sm/6 text-gray-900 hover:bg-gray-50 focus:bg-gray-50 focus:outline-hidden dark:text-white dark:hover:bg-white/5 dark:focus:bg-white/5"
                >
                  Your profile
                </.link>
                <.link
                  href={~p"/admin/sign_out"}
                  method="delete"
                  class="block px-3 py-1 text-sm/6 text-gray-900 hover:bg-gray-50 focus:bg-gray-50 focus:outline-hidden dark:text-white dark:hover:bg-white/5 dark:focus:bg-white/5"
                >
                  Sign out
                </.link>
              </el-menu>
            </el-dropdown>
          </div>
        </div>
      </div>

      <main class="py-10">
        <div class="px-4 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>
    """
  end

  attr :active, :atom, required: true
  attr :current_admin, :map, required: true

  defp sidebar_panel(assigns) do
    ~H"""
    <div class="relative flex grow flex-col gap-y-5 overflow-y-auto border-r border-gray-200 bg-white px-6 pb-4 dark:border-white/10 dark:bg-black/10 dark:ring dark:ring-white/10 dark:before:pointer-events-none dark:before:absolute dark:before:inset-0 dark:before:bg-black/10">
      <div class="relative flex h-16 shrink-0 items-center">
        <img
          src={~p"/images/ameelio_logo_square.png"}
          alt="Ameelio"
          class="h-8 w-auto"
        />
      </div>

      <nav class="relative flex flex-1 flex-col">
        <ul role="list" class="flex flex-1 flex-col gap-y-7">
          <li>
            <ul role="list" class="-mx-2 space-y-1">
              <.nav_item
                label="Users"
                to={~p"/admin/users"}
                active={@active == :users}
              >
                <:icon>
                  <path d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" stroke-linecap="round" stroke-linejoin="round" />
                </:icon>
              </.nav_item>
            </ul>
          </li>

          <li class="mt-auto">
            <.link
              href={~p"/admin/sign_out"}
              method="delete"
              class="group -mx-2 flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-300 dark:hover:bg-white/5 dark:hover:text-white"
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true" class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white">
                <path d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15M12 9l-3 3m0 0 3 3m-3-3h12.75" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
              Sign out
            </.link>
          </li>
        </ul>
      </nav>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :to, :string, required: true
  attr :active, :boolean, default: false
  slot :icon, required: true

  defp nav_item(assigns) do
    ~H"""
    <li>
      <.link
        navigate={@to}
        class={[
          "group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold",
          if(@active,
            do: "bg-gray-50 text-indigo-600 dark:bg-white/5 dark:text-white",
            else:
              "text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
          )
        ]}
      >
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
          class={[
            "size-6 shrink-0",
            if(@active,
              do: "text-indigo-600 dark:text-white",
              else:
                "text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
            )
          ]}
        >
          {render_slot(@icon)}
        </svg>
        {@label}
      </.link>
    </li>
    """
  end

  # ------------------- display helpers -------------------

  def initials(%{first_name: f, last_name: l})
      when is_binary(f) and f != "" do
    ((String.first(f) || "") <> (String.first(l || "") || ""))
    |> String.upcase()
  end

  def initials(%{username: un}) when is_binary(un) and un != "" do
    un |> String.slice(0, 2) |> String.upcase()
  end

  def initials(_), do: "·"

  def format_dt(nil), do: "—"
  def format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  def format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  def format_dt(_), do: "—"

  def short_id(nil), do: "—"
  def short_id(id) when is_binary(id), do: String.slice(id, 0, 8)
  def short_id(id), do: to_string(id)

  def display_name(%{display_name: d}) when is_binary(d) and d != "", do: d

  def display_name(%{first_name: f, last_name: l}) when is_binary(f) or is_binary(l) do
    [f, l] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")
  end

  def display_name(%{username: u}), do: u
  def display_name(_), do: "—"

  attr :roles, :list, default: []
  attr :locked_at, :any, default: nil

  def role_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% not is_nil(@locked_at) -> %>
        <span class="inline-flex items-center rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700 ring-1 ring-red-600/20 ring-inset dark:bg-red-500/10 dark:text-red-300 dark:ring-red-500/20">
          Locked
        </span>
      <% "admin" in (@roles || []) -> %>
        <span class="inline-flex items-center rounded-md bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 ring-1 ring-indigo-700/10 ring-inset dark:bg-indigo-500/10 dark:text-indigo-300 dark:ring-indigo-500/20">
          Admin
        </span>
      <% "moderator" in (@roles || []) -> %>
        <span class="inline-flex items-center rounded-md bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-800 ring-1 ring-yellow-600/20 ring-inset dark:bg-yellow-500/10 dark:text-yellow-300 dark:ring-yellow-500/20">
          Moderator
        </span>
      <% true -> %>
        <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-gray-500/10 ring-inset dark:bg-white/5 dark:text-gray-300 dark:ring-white/10">
          User
        </span>
    <% end %>
    """
  end
end
