defmodule MalanWeb.UserLive.ResetPasswordToken do
  use MalanWeb, :live_view

  require IEx

  alias Malan.Accounts
  alias Malan.Accounts.User

  alias Malan.Utils

  #import Phoenix.LiveView.Helpers

  @impl true
  def mount(%{"token" => token} = _params, _session, socket) do
    #{:ok, socket}
    #
    #peer_data = get_connect_info(socket, :peer_data)
    #require IEx; IEx.pry
    #
    user = Accounts.get_user_by_password_reset_token(token)
    # TODO:  Handle nil
    socket = assign(socket, :user, user)
    socket = assign(socket, :username, "testmpouser")
    {:ok, assign(socket, :reset_token, token)}
  end

  # @impl true
  # def render(assigns) do
  #   require IEx; IEx.pry
  #   Phoenix.View.render(MalanWeb.PageView, "page.html", assigns)
  #   Phoenix.LiveView.Helpers.live_render(assigns.socket, MalanWeb.UserLive.ResetPasswordToken)
  # end

  @impl true
  def handle_params(_params, _url, socket) do
    #{:noreply, apply_action(socket, socket.assigns.live_action, params)}
    {:noreply, socket}
  end

#  defp apply_action(socket, :edit, %{"id" => id}) do
#    socket
#    |> assign(:page_title, "Edit Page")
#    |> assign(:page, Pages.get_page!(id))
#  end
#
#  defp apply_action(socket, :new, _params) do
#    socket
#    |> assign(:page_title, "New Page")
#    |> assign(:page, %Page{})
#  end
#
#  defp apply_action(socket, :index, _params) do
#    socket
#    |> assign(:page_title, "Listing Pages")
#    |> assign(:page, nil)
#  end

  @impl true
  def handle_event("reset_password", %{"token" => _token, "password" => password}, socket) do
    # {:noreply, assign(socket, :pages, list_pages())}

    #remote_ip = nil
    remote_ip = "0.0.0.0"

    # This changeset is only used for recording the transaction.
    # The actual changeset that is used is create in the accounts module
    tx_changeset = User.update_changeset(socket.assigns.user, %{"password" => Utils.mask_str(password)})

    with {:ok, %User{} = _user} <- Accounts.reset_password_with_token(socket.assigns.user, socket.assigns.reset_token, password) do
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
        record_tx_admin_reset_password_token_fail(remote_ip, socket.assigns.user, err, tx_changeset)
        socket = assign(socket, :success, false)
        {:noreply, assign(socket, :error, err)}
    end
  end

  defp record_transaction(success?, user_id, remote_ip, who, who_username, verb, what, tx_changeset) do
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

  #def render("ameelio_logo.svg", assigns) do
  def ameelio_logo(assigns) do
    ~H"""
      <svg class="mx-auto h-12 w-auto" width="76" height="15" viewBox="0 0 76 15" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M27.4894 3.91309C25.549 3.91309 24.0613 5.14202 23.6409 6.69436C22.9941 4.55989 21.3124 3.91309 20.0511 3.91309C18.4341 3.91309 16.817 5.2067 16.4936 6.82372V4.23649H13.583V14.5854H16.4936V9.41096C16.4936 7.59989 17.2698 6.50032 18.7575 6.50032C20.2128 6.50032 21.0213 7.63223 21.0213 9.41096V14.5854H23.9319V9.41096C23.9319 7.59989 24.7081 6.50032 26.1958 6.50032C27.6511 6.50032 28.4596 7.63223 28.4596 9.41096V14.5854H31.3702V8.76415C31.3702 4.91564 29.1064 3.91309 27.4894 3.91309Z" fill="#0A0A0A" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#fef3df;"></path><path d="M55.3021 0.678955H58.2128V11.9981H60.1532V14.5853H58.2128C56.24 14.5853 55.3021 13.6475 55.3021 11.6747V0.678955Z" fill="#0A0A0A" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#fef3df;"></path><path d="M70.5021 3.91309C67.3328 3.91309 65.0043 6.17692 65.0043 9.41096C65.0043 12.645 67.3328 14.9088 70.5021 14.9088C73.6715 14.9088 76 12.645 76 9.41096C76 6.17692 73.6715 3.91309 70.5021 3.91309ZM70.5021 12.3216C68.8851 12.3216 67.5915 11.028 67.5915 9.41096C67.5915 7.79394 68.8851 6.50032 70.5021 6.50032C72.1192 6.50032 73.4128 7.79394 73.4128 9.41096C73.4128 11.028 72.1192 12.3216 70.5021 12.3216Z" fill="#0A0A0A" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#fef3df;"></path><path d="M0 9.41096C0 12.451 2.19915 14.9088 4.8834 14.9088C6.82383 14.9088 8.37617 14.165 9.05532 12.3216V14.5854H11.966V4.23649H9.05532V6.82372C8.37617 4.85096 6.79149 3.91309 4.8834 3.91309C2.19915 3.91309 0 6.37096 0 9.41096ZM2.91064 9.47564C2.91064 7.82628 4.20425 6.50032 5.82128 6.50032C7.4383 6.50032 8.73191 7.82628 8.73191 9.47564C8.73191 11.125 7.4383 12.4833 5.82128 12.4833C4.20425 12.4833 2.91064 11.125 2.91064 9.47564Z" fill="#0A0A0A" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#fef3df;"></path><path d="M41.719 10.3812H42.948C42.9803 10.0578 43.0127 9.73436 43.0127 9.41096C43.0127 6.17691 40.9429 3.91309 37.8059 3.91309C34.6688 3.91309 32.3403 6.17691 32.3403 9.41096C32.3403 12.645 34.6688 14.9088 37.8059 14.9088C39.6816 14.9088 41.525 14.1003 42.4629 12.2893L40.102 11.222C39.5846 11.9982 38.9378 12.451 37.8705 12.451C36.5769 12.451 35.6714 11.6424 35.348 10.4135L41.719 10.3812ZM37.8059 6.4033C39.0671 6.4033 39.9403 7.27649 40.2314 8.4084H35.348C35.6067 7.14713 36.5122 6.4033 37.8059 6.4033Z" fill="#F66262" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#c0867b;"></path><path d="M41.719 10.3812H42.948C42.9803 10.0578 43.0127 9.73436 43.0127 9.41096C43.0127 6.17691 40.9429 3.91309 37.8059 3.91309C34.6688 3.91309 32.3403 6.17691 32.3403 9.41096C32.3403 12.645 34.6688 14.9088 37.8059 14.9088C39.6816 14.9088 41.525 14.1003 42.4629 12.2893L40.102 11.222C39.5846 11.9982 38.9378 12.451 37.8705 12.451C36.5769 12.451 35.6714 11.6424 35.348 10.4135L41.719 10.3812ZM37.8059 6.4033C39.0671 6.4033 39.9403 7.27649 40.2314 8.4084H35.348C35.6067 7.14713 36.5122 6.4033 37.8059 6.4033Z" fill="#3577DA" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#869ba9;"></path><path d="M45.1375 10.3426H43.9086C43.8762 10.0192 43.8439 9.69579 43.8439 9.37238C43.8439 6.13834 45.9137 3.87451 49.0507 3.87451C52.1877 3.87451 54.5162 6.13834 54.5162 9.37238C54.5162 12.6064 52.1877 14.8703 49.0507 14.8703C47.175 14.8703 45.3315 14.0617 44.3937 12.2507L46.7545 11.1834C47.272 11.9596 47.9188 12.4124 48.986 12.4124C50.2796 12.4124 51.1852 11.6039 51.5086 10.3749L45.1375 10.3426ZM49.0507 6.36472C47.7894 6.36472 46.9162 7.23792 46.6252 8.36983L51.5086 8.36983C51.2498 7.10855 50.3443 6.36472 49.0507 6.36472Z" fill="#F66262" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#c0867b;"></path><path d="M45.1375 10.3426H43.9086C43.8762 10.0192 43.8439 9.69579 43.8439 9.37238C43.8439 6.13834 45.9137 3.87451 49.0507 3.87451C52.1877 3.87451 54.5162 6.13834 54.5162 9.37238C54.5162 12.6064 52.1877 14.8703 49.0507 14.8703C47.175 14.8703 45.3315 14.0617 44.3937 12.2507L46.7545 11.1834C47.272 11.9596 47.9188 12.4124 48.986 12.4124C50.2796 12.4124 51.1852 11.6039 51.5086 10.3749L45.1375 10.3426ZM49.0507 6.36472C47.7894 6.36472 46.9162 7.23792 46.6252 8.36983L51.5086 8.36983C51.2498 7.10855 50.3443 6.36472 49.0507 6.36472Z" fill="#F66262" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#c0867b;"></path><path d="M64.0341 4.23657H61.1234V14.5855H64.0341V4.23657Z" fill="#0A0A0A" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#fef3df;"></path><path d="M64.0341 0H61.1234V2.91064H64.0341V0Z" fill="#F66262" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#c0867b;"></path><path d="M64.0341 0H61.1234V2.91064H64.0341V0Z" fill="#0A0A0A" data-darkreader-inline-fill="" style="--darkreader-inline-fill:#fef3df;"></path></svg>
    """
  end
end
