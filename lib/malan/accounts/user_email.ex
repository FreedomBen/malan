defmodule Malan.Accounts.UserEmail do
  import Swoosh.Email

  def welcome_and_confirm(user) do
    new()
    #|> to({user.name, user.email})
    |> to(user)
    |> from({"Ameelio", "noreply@ameelio.org"})
    |> subject("Hello, Avengers!")
    #|> html_body("<h1>Hello #{user.first_name}</h1>")
    |> text_body("Hello #{user.first_name}\n")
  end

  def password_reset(user) do
    new()
    |> to(user)
    |> from({"Ameelio", "noreply@ameelio.org"})
    |> subject("Password Reset Token")
    #|> html_body("<h1>Hello #{user.first_name}</h1>")
    |> text_body("Hello #{user.first_name}\n")
  end
end
