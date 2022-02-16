defmodule MalanWeb.UserLive.ResetPasswordToken do
  use MalanWeb, :live_view

  # Called twice:  once on initial load and again when connected
  @impl true
  def mount(%{"token" => token}, _session, socket) do
    #{:ok, assign(socket, :pages, list_pages())}
    #{:ok, socket}

    if connected?(socket) do
      user = Accounts.get_user_by_password_reset_token(token)
      socket = assign(socket, user: user)
    end

    {:ok, assign(socket, :page, %{id: "TheID", title: "TheTitle", page: "ThePage"})}
  end

  #@impl true
  #def render(assigns) do
  #  Phoenix.View.render(MalanWeb.PageView, "page.html", assigns)
  #  Phoenix.LiveView.render(...)
  #  Phoenix.LiveView.live_render(...)
  #
  #  Phoenix.LiveView.Controller.live_render(MyLive, session: %{"user_id" => user.id})

  #end

  @impl true
  def handle_params(params, _url, socket) do
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
  def handle_event("submit_new_password", %{"id" => id}, socket) do
    # reset_password_with_token(user, token, new_password)

    # page = Pages.get_page!(id)
    # {:ok, _} = Pages.delete_page(page)

    {:noreply, assign(socket, :pages, list_pages())}
  end

#  defp list_pages do
#    Pages.list_pages()
#  end

  defp reset_password_with_token(user, token, new_password) do
    with {:ok, %User{} = _user} <- Accounts.reset_password_with_token(user, token, new_password) do
      record_transaction(
        conn,
        user.id,
        user.username,
        "PUT",
        "#UserController.admin_reset_password_token/3"
      )

      conn
      |> put_status(200)
      |> json(%{ok: true})
    else
      {:error, :missing_password_reset_token} ->
        conn
        |> put_status(401)
        |> json(%{
          ok: false,
          err: :missing_password_reset_token,
          msg: "No password reset token has been issued"
        })


      {:error, :invalid_password_reset_token} ->
        conn
        |> put_status(401)
        |> json(%{
          ok: false,
          err: :invalid_password_reset_token,
          msg: "Password reset token in invalid"
        })

      {:error, :expired_password_reset_token} ->
        conn
        |> put_status(401)
        |> json(%{
          ok: false,
          err: :expired_password_reset_token,
          msg: "Password reset token is expired"
        })
    end
  end
end
