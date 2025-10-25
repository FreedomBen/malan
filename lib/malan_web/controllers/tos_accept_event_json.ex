defmodule MalanWeb.TosAcceptEventJSON do
  alias Malan.Accounts.User.TosAcceptEvent

  def tos_accept_event(%{tos_accept_event: event}), do: event_data(event)
  def tos_accept_event(event), do: event_data(event)

  defp event_data(%TosAcceptEvent{} = event) do
    %{
      accept: event.accept,
      tos_version: event.tos_version,
      timestamp: event.timestamp
    }
  end
end
