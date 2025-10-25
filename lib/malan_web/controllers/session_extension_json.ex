defmodule MalanWeb.SessionExtensionJSON do
  use MalanWeb, :view
  alias __MODULE__

  def render("index.json", %{
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
      data: render_many(session_extensions, SessionExtensionJSON, "session_extension.json", as: :session_extension)
    }
  end

  def render("show.json", %{code: code, session_extension: session_extension}) do
    %{
      ok: true,
      code: code,
      data: render_one(session_extension, SessionExtensionJSON, "session_extension.json", as: :session_extension)
    }
  end

  def render("session_extension.json", %{session_extension: session_extension}) do
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
