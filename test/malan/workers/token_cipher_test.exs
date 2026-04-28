defmodule Malan.Workers.TokenCipherTest do
  use ExUnit.Case, async: true

  alias Malan.Workers.TokenCipher

  describe "encrypt/1 and decrypt/1" do
    test "round-trips a plaintext token" do
      token = "0123456789abcdef0123456789abcdef"
      ciphertext = TokenCipher.encrypt(token)

      assert is_binary(ciphertext)
      refute ciphertext =~ token
      assert {:ok, ^token} = TokenCipher.decrypt(ciphertext)
    end

    test "produces a different ciphertext on each call (IV is random)" do
      token = "same-token"
      assert TokenCipher.encrypt(token) != TokenCipher.encrypt(token)
    end

    test "decrypt rejects tampered ciphertext" do
      ciphertext = TokenCipher.encrypt("a-valid-token")
      tampered = ciphertext <> "x"
      assert :error = TokenCipher.decrypt(tampered)
    end

    test "decrypt rejects garbage" do
      assert :error = TokenCipher.decrypt("not a ciphertext")
    end
  end
end
