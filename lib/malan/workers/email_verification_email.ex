defmodule Malan.Workers.EmailVerificationEmail do
  @moduledoc """
  Oban worker that sends email verification emails asynchronously so the HTTP
  request isn't blocked on SMTP.

  `email_verification_token` is a virtual field on `%User{}` — only the hash is
  persisted on the user row, and the plaintext is stored only as ciphertext
  in `oban_jobs.args` (encrypted by `Malan.Workers.TokenCipher`). The worker
  decrypts on each run and re-hydrates the value onto the loaded user
  struct before rendering the email.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5

  alias Malan.Accounts
  alias Malan.Mailer
  alias Malan.Workers.TokenCipher

  @valid_contexts ~w(welcome resend email_change)

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "user_id" => user_id,
          "encrypted_token" => encrypted_token,
          "context" => context
        }
      })
      when context in @valid_contexts do
    case TokenCipher.decrypt(encrypted_token) do
      :error ->
        {:cancel, :token_decrypt_failed}

      {:ok, token} ->
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
  end

  def perform(%Oban.Job{args: %{"context" => context}}) do
    {:cancel, {:invalid_context, context}}
  end
end
