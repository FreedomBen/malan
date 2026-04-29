defmodule MalanWeb.UserLive.ResetPassword do
  use MalanWeb, :live_view

  alias Malan.{Accounts, Mailer, Utils}
  alias Malan.Accounts.User

  # Wires up socket assigns and after invokes handle_params/3
  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :remote_ip, MalanWeb.UserAuth.remote_ip(socket))}
  end

  # Handle URI and query params
  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_reset_email", %{"email" => email}, socket) do
    remote_ip = socket.assigns.remote_ip

    case Malan.RateLimits.PasswordReset.PerIp.check_rate(remote_ip) do
      {:deny, _limit} ->
        # Per-IP throttle, applied before user lookup so probing
        # nonexistent addresses still trips this bucket. The IP is the
        # visitor's CF-Connecting-IP in production (see
        # MalanWeb.UserAuth.remote_ip/1 → MalanWeb.RealIp), not the
        # Cloudflare edge.
        record_log(
          false,
          nil,
          remote_ip,
          nil,
          email,
          "POST",
          "#MalanWeb.UserLive.ResetPassword.handle_event/3 - send_reset_email - rate limited by IP #{remote_ip}",
          nil
        )

        {:noreply,
         socket
         |> assign(:too_many_requests, true)
         |> assign(:success, false)}

      _allow_or_error ->
        do_send_reset_email(socket, email, remote_ip)
    end
  end

  defp do_send_reset_email(socket, email, remote_ip) do
    case Accounts.get_user_by_email(email) do
      nil ->
        # Always render the same generic "Reset request received" message
        # whether or not the account exists, so an attacker cannot
        # enumerate valid email addresses by probing this form. The
        # internal audit log still records the submitted address so
        # abuse is investigable after the fact.
        record_log(
          false,
          nil,
          remote_ip,
          nil,
          email,
          "POST",
          "#MalanWeb.UserLive.ResetPassword.handle_event/3 - send_reset_email - no user matching submitted email",
          nil
        )

        socket =
          socket
          |> assign(:success, true)
          |> assign(:submitted_email, email)

        {:noreply, socket}

      _user ->
        # TODO:  Use pattern matching so that we can remove the Accounts.get_user_by_email call above.
        # with %User{} = user <- Accounts.get_user_by_email(email),
        with user <- Accounts.get_user_by_email(email),
             log_changeset <- User.password_reset_create_changeset(user),
             {:ok, %User{} = user} <- Accounts.generate_password_reset(user),
             {:ok, _term} <- Mailer.send_password_reset_email(user) do
          record_log(
            true,
            user.id,
            remote_ip,
            nil, # who
            user.username, # who_username
            "POST",
            "#MalanWeb.UserLive.ResetPassword.handle_event/3 - send_reset_email",
            log_changeset
          )

          socket =
            socket
            |> assign(:success, true)
            |> assign(:user, user)
            |> assign(:submitted_email, email)

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

            record_log(
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
end
