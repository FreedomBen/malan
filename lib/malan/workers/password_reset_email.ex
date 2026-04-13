defmodule Malan.Workers.PasswordResetEmail do
  @moduledoc """
  Oban worker that sends password reset emails asynchronously so the HTTP
  request isn't blocked on SMTP.

  `password_reset_token` is a virtual field on `%User{}` — only the hash is
  persisted — so the worker receives the plaintext token via job args and
  re-hydrates it onto the loaded user struct before rendering the email.
  The token is already stored as a hash in the same DB that holds
  `oban_jobs.args`, and Oban prunes completed jobs, so the extra exposure
  window is comparable to what already exists on the user row.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5

  alias Malan.Accounts
  alias Malan.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "token" => token}}) do
    case Accounts.get_user(user_id) do
      nil ->
        {:cancel, :user_not_found}

      user ->
        case Mailer.send_password_reset_email_sync(%{user | password_reset_token: token}) do
          {:ok, _term} -> :ok
          {:error, {401, _}} = err -> err
          {:error, {403, _}} = err -> err
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
