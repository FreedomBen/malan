defmodule Malan.Workers.TokenCipher do
  @moduledoc """
  Encrypt and decrypt one-time tokens that travel through Oban job args.

  Password reset and email verification tokens are stored on the user row
  only as a hash. The mailer workers need the plaintext to render the email
  link, but persisting that plaintext into `oban_jobs.args` would defeat the
  hashing — DB backups, replicas, and read-only audits would all expose live
  reset capabilities until the job row is pruned (24h by default, the same
  TTL as the reset token itself).

  This module encrypts the token before it goes into job args using a key
  derived from the endpoint's `secret_key_base`, so the persisted row is
  unreadable without that secret.
  """

  @encryption_salt "Malan oban mailer token v1 encryption"
  @signing_salt "Malan oban mailer token v1 signing"

  @spec encrypt(String.t()) :: String.t()
  def encrypt(token) when is_binary(token) do
    Plug.Crypto.MessageEncryptor.encrypt(token, encryption_key(), signing_key())
  end

  @spec decrypt(String.t()) :: {:ok, String.t()} | :error
  def decrypt(ciphertext) when is_binary(ciphertext) do
    Plug.Crypto.MessageEncryptor.decrypt(ciphertext, encryption_key(), signing_key())
  end

  defp encryption_key, do: derive(@encryption_salt)
  defp signing_key, do: derive(@signing_salt)

  defp derive(salt) do
    Plug.Crypto.KeyGenerator.generate(secret_key_base(), salt)
  end

  defp secret_key_base do
    :malan
    |> Application.fetch_env!(MalanWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
