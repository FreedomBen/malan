defmodule Malan.Mailer do
  use Swoosh.Mailer, otp_app: :malan

  alias Malan.Accounts.User
  alias Malan.Utils
  alias Malan.Utils.Logger
  alias MalanWeb.UserNotifier

  @spec send_mail(Swoosh.Email.t()) :: {:ok, term} | {:error, term}
  def send_mail(email) do
    Logger.debug(__ENV__, "Sending mail to '#{Utils.to_string(email.to)}'")

    deliver(email)
    |> log_delivery(email, __ENV__)
  end

  @doc """
  Enqueue an Oban job to deliver the password reset email asynchronously.
  This is the default path used by the HTTP controllers so SMTP latency and
  transient mail-provider failures don't block the request or leak into the
  user-visible response.
  """
  @spec send_password_reset_email(User.t()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def send_password_reset_email(%User{id: user_id, password_reset_token: token})
      when is_binary(token) do
    %{user_id: user_id, token: token}
    |> Malan.Workers.PasswordResetEmail.new()
    |> Oban.insert()
  end

  @doc """
  Deliver the password reset email synchronously. Used by the Oban worker
  and available for tests / scripts that need the inline behavior.
  """
  @spec send_password_reset_email_sync(User.t()) :: {:ok, term} | {:error, term}
  def send_password_reset_email_sync(user) do
    user
    |> UserNotifier.password_reset_email()
    |> send_mail()
  end

  @valid_email_verification_contexts [:welcome, :resend, :email_change]

  @doc """
  Enqueue an Oban job to deliver an email verification email asynchronously.

  `context` is `:welcome` (registration), `:resend` (explicit resend), or
  `:email_change` (user updated their email).
  """
  @spec send_email_verification_email(User.t(), atom()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def send_email_verification_email(%User{id: user_id, email_verification_token: token}, context)
      when is_binary(token) and context in @valid_email_verification_contexts do
    %{user_id: user_id, token: token, context: Atom.to_string(context)}
    |> Malan.Workers.EmailVerificationEmail.new()
    |> Oban.insert()
  end

  @doc """
  Deliver an email verification email synchronously (used by the Oban worker
  and by tests / scripts that need inline behavior).
  """
  @spec send_email_verification_email_sync(User.t(), atom()) :: {:ok, term} | {:error, term}
  def send_email_verification_email_sync(%User{} = user, context)
      when context in @valid_email_verification_contexts do
    user
    |> UserNotifier.email_verification_email(context)
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

    opts = [extra: %{error: err, email: Utils.to_string(email)}]

    if log_delivery_errors?() do
      Logger.error(env, msg)
      Sentry.capture_message(msg, opts)
    end

    {:error, error}
  end

  defp log_delivery({:error, {403, _} = error}, email, env) do
    msg =
      "Mail provider rejected credentials for sending mail to #{to(email)}!  #{Utils.to_string(error)}"

    if log_delivery_errors?() do
      Logger.error(env, msg)
      Sentry.capture_message(msg, extra: %{error: error, email: email})
    end

    {:error, error}
  end

  defp log_delivery({:error, error}, email, env) do
    if log_delivery_errors?() do
      Logger.warning(
        env,
        "Mail provider rejected message for #{to(email)}.  #{Utils.to_string(error)}"
      )
    end

    {:error, error}
  end

  defp to(email), do: Utils.to_string(email.to)

  defp log_delivery_errors? do
    Mix.env() != :test
  end
end
