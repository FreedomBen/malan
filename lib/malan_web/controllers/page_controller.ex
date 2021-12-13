defmodule MalanWeb.PageController do
  use MalanWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
