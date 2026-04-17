defmodule Malan.Workers.EmailVerificationEmail do
  @moduledoc """
  Oban worker that sends email verification emails asynchronously so the HTTP
  request isn't blocked on SMTP.

  `email_verification_token` is a virtual field on `%User{}` — only the hash is
  persisted — so the worker receives the plaintext token via job args and
  re-hydrates it onto the loaded user struct before rendering the email.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5

  alias Malan.Accounts
  alias Malan.Mailer

  @valid_contexts ~w(welcome resend email_change)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "token" => token, "context" => context}})
      when context in @valid_contexts do
    case Accounts.get_user(user_id) do
      nil ->
        {:cancel, :user_not_found}

      user ->
        case Mailer.send_email_verification_email_sync(
               %{user | email_verification_token: token},
               String.to_existing_atom(context)
             ) do
          {:ok, _term} -> :ok
          {:error, {401, _}} = err -> err
          {:error, {403, _}} = err -> err
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def perform(%Oban.Job{args: %{"context" => context}}) do
    {:cancel, {:invalid_context, context}}
  end
end
