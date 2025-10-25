defmodule MalanWeb.SessionJSON do
  alias Malan.Accounts
  alias Malan.Accounts.Session

  def index(%{code: code, sessions: sessions}) do
    %{ok: true, code: code, data: Enum.map(sessions, &session_data/1)}
  end

  def show(%{code: code, session: session}) do
    %{ok: true, code: code, data: session_data(session)}
  end

  def delete_all(%{code: code, num_revoked: num_revoked}) do
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

  defp session_data(%Session{} = session) do
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
      max_extension_secs: session.max_extension_secs
    }
    |> Enum.reject(fn {key, value} -> key == :api_token && is_nil(value) end)
    |> Map.new()
  end
end
