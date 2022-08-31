defmodule Malan.Mailer do
  use Swoosh.Mailer, otp_app: :malan

  alias Malan.Utils
  alias Malan.Utils.Logger
  alias MalanWeb.UserNotifier

  @spec send_mail(Swoosh.Email.t()) :: {:ok, term} | {:error, term}
  def send_mail(email) do
    Logger.debug(__ENV__, "Sending mail to '#{Utils.to_string(email.to())}'")

    deliver(email)
    |> log_delivery(email, __ENV__)
  end

  @spec send_password_reset_email(User.t()) :: {:ok, term} | {:error, term}
  def send_password_reset_email(user) do
    user
    |> UserNotifier.password_reset_email()
    |> send_mail()
  end

  defp log_delivery({:ok, term}, email, env) do
    Logger.debug(env, "Message accepted for #{to(email)}.  #{Utils.to_string(term)}")
    {:ok, term}
  end

  defp log_delivery({:error, {401, _} = error}, email, env) do
    err = Utils.to_string(error)

    msg =
      "Mail provider rejected credentials for sending mail to #{to(email)}!  #{Utils.to_string(error)}"

    opts = [error: err, email: Utils.to_string(email)]

    Logger.error(env, msg)
    Sentry.capture_message(msg, opts)

    {:error, error}
  end

  defp log_delivery({:error, {403, _} = error}, email, env) do
    msg =
      "Mail provider rejected credentials for sending mail to #{to(email)}!  #{Utils.to_string(error)}"

    Logger.error(env, msg)
    Sentry.capture_message(msg, %{error: error, email: email})

    {:error, error}
  end

  defp log_delivery({:error, error}, email, env) do
    Logger.warning(
      env,
      "Mail provider rejected message for #{to(email)}.  #{Utils.to_string(error)}"
    )

    {:error, error}
  end

  defp to(email), do: Utils.to_string(email.to())
end
