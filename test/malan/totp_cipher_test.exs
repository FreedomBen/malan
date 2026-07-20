defmodule Malan.TotpCipherTest do
  # async: false — these tests swap the TotpCipher keyring in Application env
  use Malan.DataCase, async: false

  alias Malan.Accounts
  alias Malan.Accounts.{TotpCipher, UserTotp}
  alias Malan.Test.Helpers

  @root_a :crypto.strong_rand_bytes(32)
  @root_b :crypto.strong_rand_bytes(32)

  defp b64(root), do: Base.encode64(root)

  # Override the keyring for one test, restoring the original afterwards
  # (the parsed form config/config.exs uses: ordered {key_id, root} tuples).
  defp put_keyring(keys) do
    original = Application.fetch_env!(:malan, TotpCipher)
    Application.put_env(:malan, TotpCipher, keys: keys)
    on_exit(fn -> Application.put_env(:malan, TotpCipher, original) end)
  end

  describe "parse_keyring!/1" do
    test "parses a single entry" do
      assert [{1, @root_a}] == TotpCipher.parse_keyring!("1:#{b64(@root_a)}")
    end

    test "parses an ordered multi-entry keyring (first entry is primary)" do
      assert [{2, @root_b}, {1, @root_a}] ==
               TotpCipher.parse_keyring!("2:#{b64(@root_b)},1:#{b64(@root_a)}")
    end

    test "trims whitespace around entries" do
      assert [{2, @root_b}, {1, @root_a}] ==
               TotpCipher.parse_keyring!(" 2:#{b64(@root_b)} , 1:#{b64(@root_a)} ")
    end

    test "rejects an empty string" do
      assert_raise ArgumentError, ~r/at least one/, fn ->
        TotpCipher.parse_keyring!("")
      end
    end

    test "rejects a malformed entry (no colon)" do
      assert_raise ArgumentError, ~r/not of the form/, fn ->
        TotpCipher.parse_keyring!(b64(@root_a))
      end
    end

    test "rejects a non-integer key_id" do
      for bad_id <- ["x", "1x", "-1", ""] do
        assert_raise ArgumentError, ~r/not a non-negative integer/, fn ->
          TotpCipher.parse_keyring!("#{bad_id}:#{b64(@root_a)}")
        end
      end
    end

    test "rejects a duplicate key_id" do
      assert_raise ArgumentError, ~r/duplicate key_id/, fn ->
        TotpCipher.parse_keyring!("1:#{b64(@root_a)},1:#{b64(@root_b)}")
      end
    end

    test "rejects invalid base64" do
      assert_raise ArgumentError, ~r/not valid base64/, fn ->
        TotpCipher.parse_keyring!("1:!!not-base64!!")
      end
    end

    test "rejects a root under 32 bytes" do
      short = :crypto.strong_rand_bytes(31)

      assert_raise ArgumentError, ~r/at least 32 bytes/, fn ->
        TotpCipher.parse_keyring!("1:#{b64(short)}")
      end
    end

    test "error messages never echo key material" do
      short = :crypto.strong_rand_bytes(31)

      err =
        assert_raise ArgumentError, fn ->
          TotpCipher.parse_keyring!("1:#{b64(short)}")
        end

      refute err.message =~ b64(short)
    end
  end

  describe "encrypt/1 and decrypt/2" do
    test "round-trips a secret under the primary key" do
      put_keyring([{7, @root_a}])
      secret = NimbleTOTP.secret()

      assert {7, ciphertext} = TotpCipher.encrypt(secret)
      assert ciphertext != secret
      assert TotpCipher.primary_key_id() == 7
      assert {:ok, ^secret} = TotpCipher.decrypt(ciphertext, 7)
    end

    test "decrypts rows encrypted under an older (non-primary) key" do
      put_keyring([{1, @root_a}])
      {1, old_ciphertext} = TotpCipher.encrypt("old secret")

      # rotation window: new primary added, old key retained
      put_keyring([{2, @root_b}, {1, @root_a}])

      assert {:ok, "old secret"} = TotpCipher.decrypt(old_ciphertext, 1)
      assert {2, _} = TotpCipher.encrypt("new secret")
    end

    test "fails closed when the row's key_id is absent from the keyring" do
      put_keyring([{1, @root_a}])
      {1, ciphertext} = TotpCipher.encrypt("secret")

      put_keyring([{2, @root_b}])

      assert :error = TotpCipher.decrypt(ciphertext, 1)
    end

    test "fails to decrypt with the wrong key for the claimed key_id" do
      put_keyring([{1, @root_a}])
      {1, ciphertext} = TotpCipher.encrypt("secret")

      # same key_id, different root — e.g. misconfigured keyring
      put_keyring([{1, @root_b}])

      assert :error = TotpCipher.decrypt(ciphertext, 1)
    end

    test "fails to decrypt tampered ciphertext" do
      put_keyring([{1, @root_a}])
      {1, ciphertext} = TotpCipher.encrypt("secret")

      assert :error = TotpCipher.decrypt("tampered" <> ciphertext, 1)
    end
  end

  # Insert a user_totps row encrypted under the current primary key
  defp insert_totp(user, secret) do
    {key_id, ciphertext} = TotpCipher.encrypt(secret)

    %UserTotp{}
    |> UserTotp.create_changeset(%{user_id: user.id, secret: ciphertext, key_id: key_id})
    |> Repo.insert!()
  end

  describe "Accounts.reencrypt_totp_secrets/0" do
    test "re-keys non-primary rows onto the primary key and preserves the secret" do
      put_keyring([{1, @root_a}])
      {:ok, user} = Helpers.Accounts.regular_user()
      secret = NimbleTOTP.secret()
      totp = insert_totp(user, secret)

      put_keyring([{2, @root_b}, {1, @root_a}])

      assert %{reencrypted: 1, skipped: 0, failed: 0} = Accounts.reencrypt_totp_secrets()

      reloaded = Repo.get!(UserTotp, totp.id)
      assert reloaded.key_id == 2
      assert {:ok, ^secret} = TotpCipher.decrypt(reloaded.secret, 2)
    end

    test "is idempotent: already-primary rows are left untouched" do
      put_keyring([{2, @root_b}])
      {:ok, user} = Helpers.Accounts.regular_user()
      totp = insert_totp(user, NimbleTOTP.secret())

      assert %{reencrypted: 0, skipped: 0, failed: 0} = Accounts.reencrypt_totp_secrets()

      reloaded = Repo.get!(UserTotp, totp.id)
      assert reloaded.key_id == 2
      assert reloaded.secret == totp.secret
      assert reloaded.updated_at == totp.updated_at
    end

    test "counts rows whose key_id is absent from the keyring as failed and leaves them" do
      put_keyring([{1, @root_a}])
      {:ok, user} = Helpers.Accounts.regular_user()
      totp = insert_totp(user, NimbleTOTP.secret())

      # the row's key vanishes from the ring (the operator error the
      # fail-closed contract exists for)
      put_keyring([{2, @root_b}])

      assert %{reencrypted: 0, skipped: 0, failed: 1} = Accounts.reencrypt_totp_secrets()

      reloaded = Repo.get!(UserTotp, totp.id)
      assert reloaded.key_id == 1
      assert reloaded.secret == totp.secret
    end
  end
end
