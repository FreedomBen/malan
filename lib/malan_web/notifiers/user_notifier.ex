defmodule MalanWeb.UserNotifier do
  use MalanWeb, :verified_routes

  alias Malan.Utils.Logger

  use Phoenix.Swoosh,
    view: MalanWeb.UserNotifierView,
    layout: {MalanWeb.LayoutView, :email}

  def email_verification_email(user, context) when context in [:welcome, :resend, :email_change] do
    Logger.debug(
      __ENV__,
      "Generating email_verification_email (context=#{context}) for user '#{user.email}'"
    )

    {template, subject} = email_verification_template_and_subject(context)

    new()
    |> to(user)
    |> from({"Ameelio Support Team", "noreply@ameelio.org"})
    |> subject(subject)
    |> render_body(template, %{
      user: user,
      url:
        MalanWeb.Endpoint.url() <>
          ~p"/users/verify_email/#{user.email_verification_token}"
    })
  end

  defp email_verification_template_and_subject(:welcome),
    do: {"email_verification_welcome.html", "Welcome to Malan — please verify your email"}

  defp email_verification_template_and_subject(:resend),
    do: {"email_verification_resend.html", "Verify your Malan email address"}

  defp email_verification_template_and_subject(:email_change),
    do: {"email_verification_email_change.html", "Confirm your new Malan email address"}

  def password_reset_email(user) do
    Logger.debug(__ENV__, "Generating password_reset_email for user '#{user.email}'")

    new()
    |> to(user)
    |> from({"Ameelio Support Team", "noreply@ameelio.org"})
    |> subject("Your requested password reset token")
    |> render_body("password_reset_email.html", %{
      user: user,
      url:
        MalanWeb.Endpoint.url() <>
          ~p"/users/reset_password/#{user.password_reset_token}"
      # url:
      #   ~p"/users/reset_password/#{user.password_reset_token}"
      #   |> Malan.Config.App.external_link(),
    })
  end
end
