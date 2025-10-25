defmodule MalanWeb.PageController do
  use MalanWeb, {:controller, formats: [:html]}

  def index(conn, _params) do
    render(conn, :index)
  end
end
