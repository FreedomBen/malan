defmodule MalanWeb.SessionExtensionJSON do
  alias Malan.Accounts.SessionExtension

  def index(%{
        code: code,
        page_num: page_num,
        page_size: page_size,
        session_extensions: session_extensions
      }) do
    %{
      ok: true,
      code: code,
      page_num: page_num,
      page_size: page_size,
      data: Enum.map(session_extensions, &session_extension_data/1)
    }
  end

  def show(%{code: code, session_extension: session_extension}) do
    %{
      ok: true,
      code: code,
      data: session_extension_data(session_extension)
    }
  end

  defp session_extension_data(%SessionExtension{} = session_extension) do
    %{
      id: session_extension.id,
      old_expires_at: session_extension.old_expires_at,
      new_expires_at: session_extension.new_expires_at,
      extended_by_seconds: session_extension.extended_by_seconds,
      extended_by_session: session_extension.extended_by_session,
      extended_by_user: session_extension.extended_by_user,
      session_id: session_extension.session_id,
      user_id: session_extension.user_id
    }
  end
end
