defmodule MalanWeb.UserLive.VerifyEmail do
  @moduledoc """
  Authenticated request/resend page for email verification.  Unauthenticated
  visitors are redirected to login by the `:require_authed_user` on_mount hook
  (wired in the router).
  """

  use MalanWeb, :live_view

  alias Malan.{Accounts, Mailer}
  alias Malan.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:user, user)
      |> assign(:success, nil)
      |> assign(:status, nil)
      |> assign(:error, nil)
      |> assign(:too_many_requests, false)
      |> assign(:remote_ip, MalanWeb.UserAuth.remote_ip(socket))

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("send_verification_email", _params, socket) do
    user = socket.assigns.user
    remote_ip = socket.assigns.remote_ip

    meta = %{ip: remote_ip}

    result =
      Accounts.generate_email_verification(user,
        rate_limit?: true,
        context: :resend,
        meta: meta
      )

    socket =
      case result do
        {:ok, %User{} = user_with_token} ->
          Mailer.send_email_verification_email(user_with_token, :resend)

          socket
          |> assign(:success, true)
          |> assign(:status, :sent)
          |> assign(:error, nil)

        {:ok, :already_verified} ->
          socket
          |> assign(:success, true)
          |> assign(:status, :already_verified)
          |> assign(:error, nil)

        {:ok, :skipped_domain} ->
          socket
          |> assign(:success, true)
          |> assign(:status, :skipped_domain)

        {:ok, :skipped_auto_send_disabled} ->
          socket
          |> assign(:success, true)
          |> assign(:status, :skipped_auto_send_disabled)

        {:error, :too_many_requests} ->
          socket
          |> assign(:too_many_requests, true)
          |> assign(:success, false)

        {:error, err} ->
          socket
          |> assign(:error, err)
          |> assign(:success, false)
      end

    {:noreply, socket}
  end
end
