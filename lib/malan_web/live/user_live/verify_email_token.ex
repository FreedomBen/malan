defmodule MalanWeb.UserLive.VerifyEmailToken do
  @moduledoc """
  Token confirmation page.  Accessible without authentication — the raw token
  is the capability.  GET/mount does **not** consume the token so link-prefetch
  bots can't burn it; verification happens only when the user clicks "Confirm".
  """

  use MalanWeb, :live_view

  alias Malan.Accounts

  @impl true
  def mount(%{"token" => token} = _params, _session, socket) do
    # Lookup the user (best-effort, no state mutation)
    user = Accounts.get_user_by_email_verification_token(token)

    socket =
      socket
      |> assign(:verify_token, token)
      |> assign(:user, user)
      |> assign(:status, :pending)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("confirm_verify", params, socket) do
    # Allow the user to paste a different token into the form
    token =
      case Map.get(params, "token") do
        t when is_binary(t) and t != "" -> t
        _ -> socket.assigns.verify_token
      end

    user =
      socket.assigns.user || Accounts.get_user_by_email_verification_token(token)

    socket =
      case Accounts.verify_email_with_token(user, token) do
        {:ok, _user} ->
          socket
          |> assign(:status, :verified)
          |> assign(:error, nil)

        {:error, reason} ->
          socket
          |> assign(:status, reason)
          |> assign(:error, reason)
      end

    {:noreply, socket}
  end
end
