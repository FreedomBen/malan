defmodule Malan.Workers.PasswordResetEmailTest do
  use Malan.DataCase, async: true
  use Oban.Testing, repo: Malan.Repo

  import Swoosh.TestAssertions

  alias Malan.Accounts
  alias Malan.Mailer
  alias Malan.Test.Helpers
  alias Malan.Workers.PasswordResetEmail
  alias Malan.Workers.TokenCipher

  describe "perform/1" do
    test "delivers the password reset email using the encrypted token from args" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_password_reset(user, :no_rate_limit)

      assert :ok =
               perform_job(PasswordResetEmail, %{
                 "user_id" => user.id,
                 "encrypted_token" => TokenCipher.encrypt(user.password_reset_token)
               })

      assert_email_sent(fn email ->
        assert {_name, addr} = List.first(email.to)
        assert addr == user.email
        assert email.html_body =~ user.password_reset_token
      end)
    end

    test "cancels when the user no longer exists" do
      assert {:cancel, :user_not_found} =
               perform_job(PasswordResetEmail, %{
                 "user_id" => Ecto.UUID.generate(),
                 "encrypted_token" => TokenCipher.encrypt("irrelevant")
               })
    end

    test "cancels when the encrypted token cannot be decrypted" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:cancel, :token_decrypt_failed} =
               perform_job(PasswordResetEmail, %{
                 "user_id" => user.id,
                 "encrypted_token" => "not a real ciphertext"
               })
    end
  end

  describe "Mailer.send_password_reset_email/1 enqueue" do
    test "enqueues a job carrying user_id and an encrypted token" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_password_reset(user, :no_rate_limit)

      # Switch to manual mode for this assertion so the job is inspected,
      # not executed inline.
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{} = job} = Mailer.send_password_reset_email(user)
        assert job.worker == "Malan.Workers.PasswordResetEmail"
        assert job.queue == "mailers"
        args = for {k, v} <- job.args, into: %{}, do: {to_string(k), v}
        assert args["user_id"] == user.id
        refute Map.has_key?(args, "token")
        assert is_binary(args["encrypted_token"])
        refute args["encrypted_token"] =~ user.password_reset_token
        assert {:ok, plaintext} = TokenCipher.decrypt(args["encrypted_token"])
        assert plaintext == user.password_reset_token
      end)
    end
  end
end
