defmodule MalanWeb.PrivacyPolicyAcceptEventJSON do
  alias Malan.Accounts.User.PrivacyPolicyAcceptEvent

  def privacy_policy_accept_event(%{privacy_policy_accept_event: event}), do: event_data(event)
  def privacy_policy_accept_event(event), do: event_data(event)

  defp event_data(%PrivacyPolicyAcceptEvent{} = event) do
    %{
      accept: event.accept,
      privacy_policy_version: event.privacy_policy_version,
      timestamp: event.timestamp
    }
  end
end
