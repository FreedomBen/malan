defmodule Malan.Accounts.TotpCipher do
  @moduledoc """
  Encrypt and decrypt TOTP secrets at rest (`user_totps.secret`).

  Unlike password hashes, TOTP secrets must remain recoverable — every login
  re-derives the expected code from the plaintext secret — so they are
  encrypted rather than hashed. Key material comes from the `TOTP_ENCRYPTION_KEYS`
  environment variable (see `config/runtime.exs`), an ordered keyring of
  `"<key_id>:<base64>"` entries: the first entry encrypts, all entries
  decrypt. `user_totps.key_id` records which entry encrypted each row, so
  keys rotate without user re-enrollment: add the new key as the first
  entry, deploy, run `Malan.Release.reencrypt_totp_secrets/0`, then remove
  the old key.

  Deliberately independent of `secret_key_base` (contrast
  `Malan.Workers.TokenCipher`) so rotating cookie secrets cannot brick MFA
  logins. Decryption fails closed: a row whose `key_id` is absent from the
  keyring returns `:error` rather than trying other keys or skipping MFA.
  """

  @encryption_salt "Malan user_totps secret v1 encryption"
  @signing_salt "Malan user_totps secret v1 signing"

  @min_root_bytes 32

  @typedoc "Ordered keyring: first entry encrypts, all entries decrypt."
  @type keyring :: [{key_id :: non_neg_integer(), root :: binary()}]

  @doc """
  Encrypt `plaintext` under the primary (first) keyring entry.

  Returns `{key_id, ciphertext}` so the caller can persist which key was
  used alongside the ciphertext.
  """
  @spec encrypt(binary()) :: {non_neg_integer(), binary()}
  def encrypt(plaintext) when is_binary(plaintext) do
    {key_id, root} = primary_key()

    {key_id,
     Plug.Crypto.MessageEncryptor.encrypt(plaintext, encryption_key(root), signing_key(root))}
  end

  @doc """
  Decrypt `ciphertext` with the keyring entry identified by `key_id`.

  Fails closed: returns `:error` when `key_id` is not in the keyring (or the
  ciphertext does not authenticate) rather than trying other keys.
  """
  @spec decrypt(binary(), integer()) :: {:ok, binary()} | :error
  def decrypt(ciphertext, key_id) when is_binary(ciphertext) do
    case List.keyfind(keyring(), key_id, 0) do
      {^key_id, root} ->
        Plug.Crypto.MessageEncryptor.decrypt(ciphertext, encryption_key(root), signing_key(root))

      nil ->
        :error
    end
  end

  @doc "The `{key_id, root}` entry new encryptions use (first keyring entry)."
  @spec primary_key() :: {non_neg_integer(), binary()}
  def primary_key, do: keyring() |> List.first()

  @doc "The `key_id` new encryptions use."
  @spec primary_key_id() :: non_neg_integer()
  def primary_key_id, do: primary_key() |> elem(0)

  @doc """
  Parse and validate a `TOTP_ENCRYPTION_KEYS` string into a `t:keyring/0`.

  Format: `"<key_id>:<base64>[,<key_id>:<base64>,...]"` where `key_id` is a
  non-negative integer and the base64 decodes to a root secret of at least
  #{@min_root_bytes} bytes. Raises `ArgumentError` on a malformed entry, a
  non-integer or duplicate `key_id`, or a too-short root — called from
  `config/runtime.exs`, so a bad keyring refuses boot rather than running
  weak or ambiguous. The length floor matters because
  `Plug.Crypto.KeyGenerator` silently stretches a short root instead of
  rejecting it. Error messages never echo key material.
  """
  @spec parse_keyring!(String.t()) :: keyring()
  def parse_keyring!(keys_string) when is_binary(keys_string) do
    entries =
      keys_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if entries == [] do
      raise ArgumentError,
            "TOTP_ENCRYPTION_KEYS must contain at least one \"<key_id>:<base64>\" entry"
    end

    keyring = Enum.map(entries, &parse_entry!/1)

    key_ids = Enum.map(keyring, &elem(&1, 0))
    duplicate_ids = Enum.uniq(key_ids -- Enum.uniq(key_ids))

    if duplicate_ids != [] do
      raise ArgumentError,
            "TOTP_ENCRYPTION_KEYS contains duplicate key_id(s): #{Enum.join(duplicate_ids, ", ")}"
    end

    keyring
  end

  defp parse_entry!(entry) do
    case String.split(entry, ":", parts: 2) do
      [key_id_s, base64] ->
        {parse_key_id!(key_id_s), parse_root!(key_id_s, base64)}

      _ ->
        raise ArgumentError,
              "TOTP_ENCRYPTION_KEYS entry is not of the form \"<key_id>:<base64>\""
    end
  end

  defp parse_key_id!(key_id_s) do
    if key_id_s =~ ~r/\A\d+\z/ do
      String.to_integer(key_id_s)
    else
      raise ArgumentError,
            "TOTP_ENCRYPTION_KEYS key_id #{inspect(key_id_s)} is not a non-negative integer"
    end
  end

  defp parse_root!(key_id_s, base64) do
    case Base.decode64(base64) do
      {:ok, root} when byte_size(root) >= @min_root_bytes ->
        root

      {:ok, _too_short} ->
        raise ArgumentError,
              "TOTP_ENCRYPTION_KEYS key_id #{key_id_s}: root secret must be at least " <>
                "#{@min_root_bytes} bytes before base64 encoding"

      :error ->
        raise ArgumentError,
              "TOTP_ENCRYPTION_KEYS key_id #{key_id_s}: value is not valid base64"
    end
  end

  defp keyring do
    :malan
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:keys)
  end

  defp encryption_key(root), do: derive(root, @encryption_salt)
  defp signing_key(root), do: derive(root, @signing_salt)

  defp derive(root, salt) do
    Plug.Crypto.KeyGenerator.generate(root, salt)
  end
end
