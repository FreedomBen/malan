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
    socket = assign(socket, :username, "testmpouser")
    {:ok, assign(socket, :reset_token, token)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_password", %{"token" => _token, "password" => password}, socket) do
    remote_ip = "0.0.0.0"

    # This changeset is only used for recording the transaction.
    # The actual changeset that is used is create in the accounts module
    tx_changeset =
      User.update_changeset(socket.assigns.user, %{"password" => Utils.mask_str(password)})

    with {:ok, %User{} = _user} <-
           Accounts.reset_password_with_token(
             socket.assigns.user,
             socket.assigns.reset_token,
             password
           ) do
      record_transaction(
        true,
        socket.assigns.user.id,
        remote_ip,
        nil, # who
        socket.assigns.user.username, # who_username
        "PUT",
        "MalanWeb.UserLive.ResetPasswordToken | handle_event 'reset_password'",
        tx_changeset
      )

      {:noreply, assign(socket, :success, true)}
    else
      {:error, err} ->
        record_tx_admin_reset_password_token_fail(
          remote_ip,
          socket.assigns.user,
          err,
          tx_changeset
        )

        socket = assign(socket, :success, false)
        {:noreply, assign(socket, :error, err)}
    end
  end

  defp record_transaction(
         success?,
         user_id,
         remote_ip,
         who,
         who_username,
         verb,
         what,
         tx_changeset
       ) do
    Accounts.record_transaction(
      success?,
      user_id,
      nil, # session_id
      who,
      who_username,
      "users", # type
      verb,
      what,
      remote_ip,
      tx_changeset
    )
  end

  defp record_tx_admin_reset_password_token_fail(remote_ip, user, err, tx_changeset) do
    record_transaction(
      false, # success
      user.id,
      remote_ip,
      user.id,
      user.username,
      "PUT", # verb
      "MalanWeb.UserLive.ResetPasswordToken - Err: #{Malan.Utils.Ecto.Changeset.errors_to_str_list(err)}",
      tx_changeset
    )
  end
end
