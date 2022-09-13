defmodule MalanWeb.UserLive.ResetPassword do
  use MalanWeb, :live_view

  alias Malan.{Accounts, Mailer, Utils}
  alias Malan.Accounts.User

  # Wires up socket assigns and after invokes handle_params/3
  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  # Handle URI and query params
  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_reset_email", %{"email" => email}, socket) do
    remote_ip = "0.0.0.0"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:noreply, assign(socket, :success, false)}

      _user ->
        # TODO:  Use pattern matching so that we can remove the Accounts.get_user_by_email call above.
        #with %User{} = user <- Accounts.get_user_by_email(email),
        with user <- Accounts.get_user_by_email(email),
             tx_changeset <- User.password_reset_create_changeset(user),
             {:ok, %User{} = user} <- Accounts.generate_password_reset(user),
             {:ok, _term} <- Mailer.send_password_reset_email(user) do
          record_transaction(
            true,
            user.id,
            remote_ip,
            nil, # who
            user.username, # who_username
            "POST",
            "#MalanWeb.UserLive.ResetPassword.handle_event/3 - send_reset_email",
            tx_changeset
          )

          socket =
            socket
            |> assign(:success, true)
            |> assign(:user, user)

          {:noreply, socket}
        else
          # {:error, :too_many_requests}
          # {:error, changeset}
          {:error, err_cs} ->
            err_str =
              case err_cs do
                %Ecto.Changeset{} -> Utils.Ecto.Changeset.errors_to_str(err_cs)
                _ -> Utils.to_string(err_cs)
              end

            cs_or_atom =
              case err_cs do
                :too_many_requests -> nil
                _ -> err_cs
              end

            record_transaction(
              false,
              nil, # user ID
              remote_ip,
              nil, # who
              email, # who_username
              "POST",
              "#MalanWeb.UserLive.ResetPassword.handle_event/3 - send_reset_email.  Failed to send user email.  #{err_str}",
              nil
            )

            socket =
              case err_cs do
                :too_many_requests -> assign(socket, :too_many_requests, true)
                {401, _} -> assign(socket, :internal_error, true)
                _ -> assign(socket, :error, cs_or_atom)
              end
              |> assign(:error, cs_or_atom)
              |> assign(:success, false)

            {:noreply, socket}
        end
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
end
