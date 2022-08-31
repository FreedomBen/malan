defmodule MalanWeb.UserNotifier do
  alias Malan.Utils.Logger

  use Phoenix.Swoosh,
    view: MalanWeb.UserNotifierView,
    layout: {MalanWeb.LayoutView, :email}

  def welcome_and_confirm_email(user) do
    Logger.debug(__ENV__, "Generating password_reset_email for user '#{user.email}'")

    new()
    # |> to({user.name, user.email})
    |> to(user)
    |> from({"Malan", "noreply@example.com"})
    |> subject("Hello, Avengers!")
    |> render_body("welcome_confirm_email.html", %{name: user.name})

    # |> render_html("<h1>Hello</h1>")
  end

  def password_reset_email(user) do
    Logger.debug(__ENV__, "Generating password_reset_email for user '#{user.email}'")

    new()
    |> to(user)
    |> from({"Ameelio Support Team", "noreply@ameelio.org"})
    |> subject("Your requested password reset token")
    |> render_body("password_reset_email.html", %{
      user: user,
      url: "https://ameelio.org/users/reset_password/#{user.password_reset_token}"
    })

    # password_reset_token: user.password_reset_token,
    # password_reset_token_expires_at: user.password_reset_token_expires_at
  end
end
