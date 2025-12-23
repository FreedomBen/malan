defmodule MalanWeb.ModalComponent do
  use MalanWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    If you want to use this component, you need to update the live_patch and live_component
    functions below.  See:  https://hexdocs.pm/phoenix_live_view/changelog.html#0-18-0-2022-09-20
    """

    # ~H"""
    # <div
    #   id={@id}
    #   class="phx-modal"
    #   phx-capture-click="close"
    #   phx-window-keydown="close"
    #   phx-key="escape"
    #   phx-target={@myself}
    #   phx-page-loading>

    #   <div class="phx-modal-content">
    #     <%= live_patch raw("&times;"), to: @return_to, class: "phx-modal-close" %>
    #     <%= live_component @component, @opts %>
    #   </div>
    # </div>
    # """
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end
end
