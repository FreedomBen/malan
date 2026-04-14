defmodule MalanWeb.AdminLive.UserDetail do
  use MalanWeb, :live_view

  on_mount {MalanWeb.AdminAuth, :require_admin}

  alias Malan.Accounts
  alias Malan.Accounts.User

  @safe_fields ~w(
    first_name middle_name last_name
    name_prefix name_suffix
    nick_name display_name
    sex gender ethnicity
    birthday weight height
  )

  @session_page_size 20

  def safe_fields, do: @safe_fields

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "No user with id #{id}.")
         |> push_navigate(to: ~p"/admin/users")}

      %User{} = user ->
        {:ok,
         socket
         |> assign(
           page_title: "User · " <> (user.username || id),
           user: user,
           form: to_form(build_changeset(user, %{})),
           saved?: false,
           sessions: load_sessions(user)
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset), saved?: false)}
  end

  def handle_event("save", %{"user" => params}, socket) do
    filtered = Map.take(params, @safe_fields)

    case Accounts.admin_update_user(socket.assigns.user, filtered) do
      {:ok, %User{} = user} ->
        {:noreply,
         socket
         |> assign(
           user: user,
           form: to_form(build_changeset(user, %{})),
           saved?: true,
           sessions: load_sessions(user)
         )
         |> put_flash(:info, "Saved changes to #{user.username}.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(form: to_form(changeset), saved?: false)
         |> put_flash(:error, "Could not save. Please check the highlighted fields.")}
    end
  end

  defp build_changeset(user, params) do
    # Use admin_changeset but limit casts to safe fields only
    params = Map.take(params, @safe_fields)
    User.admin_changeset(user, params)
  end

  defp load_sessions(user) do
    Accounts.list_sessions(user, 0, @session_page_size)
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :span, :integer, default: 3

  def admin_text_field(assigns) do
    ~H"""
    <div class={span_class(@span)}>
      <label
        for={"user_" <> Atom.to_string(@field)}
        class="block text-sm/6 font-medium text-gray-900 dark:text-white"
      >
        {@label}
      </label>
      <div class="mt-2">
        <input
          id={"user_" <> Atom.to_string(@field)}
          name={@form.name <> "[" <> Atom.to_string(@field) <> "]"}
          type={@type}
          value={format_value(@form[@field].value)}
          class="block w-full rounded-md bg-white px-3 py-1.5 text-base text-gray-900 outline-1 -outline-offset-1 outline-gray-300 placeholder:text-gray-400 focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600 sm:text-sm/6 dark:bg-white/5 dark:text-white dark:outline-white/10 dark:focus:outline-indigo-500"
        />
      </div>
      <%= for msg <- field_errors(@form, @field) do %>
        <p class="mt-1 text-xs text-red-600 dark:text-red-400">{msg}</p>
      <% end %>
    </div>
    """
  end

  defp field_errors(form, field) do
    form[field].errors
    |> Enum.map(fn
      {msg, opts} when is_binary(msg) ->
        Enum.reduce(opts, msg, fn {k, v}, acc ->
          String.replace(acc, "%{#{k}}", to_string(v))
        end)

      msg when is_binary(msg) ->
        msg

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp span_class(1), do: "sm:col-span-1"
  defp span_class(2), do: "sm:col-span-2"
  defp span_class(3), do: "sm:col-span-3"
  defp span_class(4), do: "sm:col-span-4"
  defp span_class(5), do: "sm:col-span-5"
  defp span_class(6), do: "sm:col-span-6"
  defp span_class(_), do: "sm:col-span-3"

  defp format_value(nil), do: ""
  defp format_value(%Date{} = d), do: Date.to_iso8601(d)
  defp format_value(%DateTime{} = d), do: DateTime.to_iso8601(d)
  defp format_value(%Decimal{} = d), do: Decimal.to_string(d)
  defp format_value(val), do: to_string(val)

  def session_status(session) do
    now = DateTime.utc_now()

    cond do
      not is_nil(session.revoked_at) -> :revoked
      not is_nil(session.expires_at) and DateTime.compare(session.expires_at, now) == :lt -> :expired
      true -> :active
    end
  end
end
