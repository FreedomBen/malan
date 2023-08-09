defmodule MalanWeb.SessionView do
  use MalanWeb, :view

  alias Malan.Accounts

  alias MalanWeb.SessionView

  def render("index.json", %{code: code, sessions: sessions}) do
    %{ok: true, code: code, data: render_many(sessions, SessionView, "session.json")}
  end

  def render("show.json", %{code: code, session: session}) do
    %{ok: true, code: code, data: render_one(session, SessionView, "session.json")}
  end

  def render("session.json", %{session: session}) do
    %{
      id: session.id,
      user_id: session.user_id,
      api_token: session.api_token,
      expires_at: session.expires_at,
      authenticated_at: session.authenticated_at,
      revoked_at: session.revoked_at,
      ip_address: session.ip_address,
      valid_only_for_ip: session.valid_only_for_ip,
      valid_only_for_approved_ips: session.valid_only_for_approved_ips,
      location: session.location,
      is_valid: Accounts.session_valid_bool?(session.expires_at, session.revoked_at),
      extendable_until: session.extendable_until,
      max_extension_secs: session.max_extension_secs,
    }
    |> Enum.reject(fn {k, v} -> k == :api_token && is_nil(v) end)
    |> Enum.into(%{})
  end

  def render("delete_all.json", %{code: code, num_revoked: num_revoked}) do
    %{
      ok: true,
      code: code,
      data: %{
        status: true,
        num_revoked: num_revoked,
        message: "Successfully revoked #{num_revoked} session"
      }
    }
  end
end
