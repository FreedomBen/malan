defmodule MalanWeb.SessionView do
  use MalanWeb, :view

  alias Malan.Accounts
  alias Malan.Accounts.Session

  alias MalanWeb.SessionView

  def render("index.json", %{sessions: sessions}) do
    %{data: render_many(sessions, SessionView, "session.json")}
  end

  def render("show.json", %{session: session}) do
    %{data: render_one(session, SessionView, "session.json")}
  end

  def render("session.json", %{session: session}) do
    %{
      id: session.id,
      user_id: session.user_id,
      api_token: session.api_token,
      expires_at: session.expires_at,
      authenticated_at: session.authenticated_at,
      revoked_at: session.revoked_at,
      ip_address: get_ip_address(session),
      location: session.location,
      is_valid: Accounts.session_valid_bool?(session.expires_at, session.revoked_at)
    }
    |> Enum.reject(fn {k, v} -> k == :api_token && is_nil(v) end)
    |> Enum.into(%{})
  end

  def render("delete_all.json", %{num_revoked: num_revoked}) do
    %{
      data: %{
        status: true,
        num_revoked: num_revoked,
        message: "Successfully revoked #{num_revoked} session"
      }
    }
  end

  defp get_ip_address(%Session{ip_address: ip, real_ip_address: nil}), do: ip
  defp get_ip_address(%Session{real_ip_address: rip}), do: rip
  defp get_ip_address(%Session{ip_address: ip}), do: ip
  defp get_ip_address(_), do: ""
end
