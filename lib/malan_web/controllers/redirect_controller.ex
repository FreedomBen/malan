defmodule MalanWeb.RedirectController do
  use MalanWeb, {:controller, formats: [:html]}

  def reset_password(conn, _params) do
    redirect(conn, to: ~p"/users/reset_password")
  end
end
