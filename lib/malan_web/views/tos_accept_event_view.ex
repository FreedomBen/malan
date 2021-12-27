defmodule MalanWeb.TosAcceptEventView do
  use MalanWeb, :view
  alias MalanWeb.TosAcceptEventView

  def render("tos_accept_event.json", %{tos_accept_event: tos_accept_event}) do
    %{
      accept: tos_accept_event.accept,
      tos_version: tos_accept_event.tos_version,
      timestamp: tos_accept_event.timestamp
    }
  end
end
