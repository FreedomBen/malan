defmodule MalanWeb.PrivacyPolicyAcceptEventView do
  use MalanWeb, :view
  alias MalanWeb.PrivacyPolicyAcceptEventView

  def render("privacy_policy_accept_event.json", %{
        privacy_policy_accept_event: privacy_policy_accept_event
      }) do
    %{
      accept: privacy_policy_accept_event.accept,
      privacy_policy_version: privacy_policy_accept_event.privacy_policy_version,
      timestamp: privacy_policy_accept_event.timestamp
    }
  end
end
