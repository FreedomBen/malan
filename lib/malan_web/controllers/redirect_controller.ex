defmodule MalanWeb.RedirectController do
  use MalanWeb, :controller

  def reset_password(conn, _params) do
    redirect(conn, to: Routes.live_path(conn, MalanWeb.UserLive.ResetPassword))
  end
end
