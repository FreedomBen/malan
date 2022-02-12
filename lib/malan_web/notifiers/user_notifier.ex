defmodule MalanWeb.UserNotifier do
  use Phoenix.Swoosh,
    view: MalanWeb.NotifierView,
    layout: {MalanWeb.LayoutView, :email}

  def welcome(user) do
    new()
    |> from("tony@stark.com")
    |> to(user.email)
    |> subject("Hello, Avengers!")
    |> render_body("welcome.html", %{name: user.name})
  end
end
