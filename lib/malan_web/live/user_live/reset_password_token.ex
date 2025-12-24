defmodule MalanWeb.UserLive.ResetPasswordToken do
  use MalanWeb, :live_view

  require IEx

  alias Malan.Accounts
  alias Malan.Accounts.User

  alias Malan.Utils

  @impl true
  def mount(%{"token" => token} = _params, _session, socket) do
    user = Accounts.get_user_by_password_reset_token(token)

    socket = assign(socket, :user, user)
    {:ok, assign(socket, :reset_token, token)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_password", %{"password" => password} = params, socket) do
    remote_ip = "0.0.0.0"

    # If the form value for token is set, use that for the reset token.  That way
    # if users can't click the link, they can open the page and paste in the token.
    # Otherwise, use the token that originally opened this session.
    reset_token =
      case Map.has_key?(params, "token") do
        true -> Map.get(params, "token")
        _ -> socket.assigns.reset_token
      end

    # This is used to try to avoid burning the reset token on a server-side
    # password validation failure.  This doesn't remove the server-side validation
    # that happens.  It still goes through the other validation, but if we can
    # catch it early then the user doesn't have to request a new token for every
    # attempt they want to make. Secondarily it slso give us a changset
    # to use for logging the log
    log_changeset = User.update_changeset(socket.assigns.user, %{"password" => password})

    socket =
      case log_changeset.valid? do
        true -> handle_reset_password(reset_token, password, socket, remote_ip, log_changeset)
        _ -> handle_reset_password_fail(log_changeset, socket, remote_ip)
      end

    {:noreply, socket}
  end

  defp handle_reset_password(reset_token, new_password, socket, remote_ip, log_changeset) do
    with {:ok, %User{} = _user} <-
           Accounts.reset_password_with_token(
             socket.assigns.user,
             reset_token,
             new_password
           ) do
      record_log(
        true,
        socket.assigns.user.id,
        remote_ip,
        nil, # who
        socket.assigns.user.username, # who_username
        "PUT",
        "MalanWeb.UserLive.ResetPasswordToken | handle_event 'reset_password'",
        log_changeset
      )

      socket
      |> assign(:success, true)
      |> assign(:error, nil)
    else
      {:error, err} ->
        handle_reset_password_fail(err, socket, remote_ip)
    end
  end

  defp handle_reset_password_fail(err, socket, remote_ip) do
    record_log_admin_reset_password_token_fail(
      remote_ip,
      socket.assigns.user,
      err
    )

    socket
    |> assign(:success, false)
    |> assign(:error, err)
  end

  defp record_log(
         success?,
         user_id,
         remote_ip,
         who,
         who_username,
         verb,
         what,
         log_changeset
       ) do
    Accounts.record_log(
      success?,
      user_id,
      nil, # session_id
      who,
      who_username,
      "users", # type
      verb,
      what,
      remote_ip,
      log_changeset
    )
  end

  defp record_log_admin_reset_password_token_fail(remote_ip, user, err) do
    record_log(
      false, # success
      user.id,
      remote_ip,
      user.id,
      user.username,
      "PUT", # verb
      "MalanWeb.UserLive.ResetPasswordToken - Err: #{Malan.Utils.Ecto.Changeset.errors_to_str_list(err)}",
      err
    )
  end

  defp token_text_input(assigns) do
    bg_color =
      case assigns.disabled do
        true -> "bg-gray-100"
        false -> ""
      end

    assigns = assign(assigns, :bg_color, bg_color)

    ~H"""
    <input
      value={assigns.reset_token}
      id="reset_token"
      name="token"
      type="text"
      pattern="[0-9a-zA-Z]*"
      required={true}
      disabled={assigns.disabled}
      class={"appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm #{@bg_color}"}
    />
    """
  end

  defp password_reset_form(assigns) do
    ~H"""
    <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
      <div class="bg-white py-8 px-4 shadow-lg sm:rounded-lg sm:px-10">
        <form class="space-y-6" phx-change="" phx-submit="reset_password">
          <div>
            <label for="reset_token" class="block text-sm font-medium text-gray-700">
              Password Reset Token (from email):
            </label>
            <div class="mt-1">
              <.token_text_input
                reset_token={assigns.reset_token}
                disabled={
                  !(Utils.nil_or_empty?(assigns.reset_token) || assigns.reset_token == "token")
                }
              />
            </div>
          </div>

          <div>
            <label for="password" class="block text-sm font-medium text-gray-700">
              New Password:
            </label>
            <div class="mt-1">
              <input
                id="password"
                name="password"
                type="password"
                autocomplete="current-password"
                required
                class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              />
            </div>
          </div>

          <div>
            <button class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Set new password
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
