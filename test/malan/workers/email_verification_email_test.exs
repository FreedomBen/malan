defmodule Malan.Workers.EmailVerificationEmailTest do
  use Malan.DataCase, async: true
  use Oban.Testing, repo: Malan.Repo

  import Swoosh.TestAssertions

  alias Malan.Accounts
  alias Malan.Mailer
  alias Malan.Test.Helpers
  alias Malan.Workers.EmailVerificationEmail
  alias Malan.Workers.TokenCipher

  describe "perform/1" do
    test "delivers the verification email using the encrypted token from args (welcome context)" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      assert :ok =
               perform_job(EmailVerificationEmail, %{
                 "user_id" => user.id,
                 "encrypted_token" => TokenCipher.encrypt(user.email_verification_token),
                 "context" => "welcome"
               })

      assert_email_sent(fn email ->
        assert {_name, addr} = List.first(email.to)
        assert addr == user.email
        assert email.subject == "Welcome to Malan — please verify your email"
        assert email.html_body =~ user.email_verification_token
      end)
    end

    test "uses resend subject for :resend context" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      assert :ok =
               perform_job(EmailVerificationEmail, %{
                 "user_id" => user.id,
                 "encrypted_token" => TokenCipher.encrypt(user.email_verification_token),
                 "context" => "resend"
               })

      assert_email_sent(fn email ->
        assert email.subject == "Verify your Malan email address"
      end)
    end

    test "uses email_change subject for :email_change context" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      assert :ok =
               perform_job(EmailVerificationEmail, %{
                 "user_id" => user.id,
                 "encrypted_token" => TokenCipher.encrypt(user.email_verification_token),
                 "context" => "email_change"
               })

      assert_email_sent(fn email ->
        assert email.subject == "Confirm your new Malan email address"
      end)
    end

    test "cancels when user no longer exists" do
      assert {:cancel, :user_not_found} =
               perform_job(EmailVerificationEmail, %{
                 "user_id" => Ecto.UUID.generate(),
                 "encrypted_token" => TokenCipher.encrypt("irrelevant"),
                 "context" => "welcome"
               })
    end

    test "cancels when the encrypted token cannot be decrypted" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:cancel, :token_decrypt_failed} =
               perform_job(EmailVerificationEmail, %{
                 "user_id" => user.id,
                 "encrypted_token" => "not a real ciphertext",
                 "context" => "welcome"
               })
    end

    test "cancels on unknown context" do
      assert {:cancel, {:invalid_context, "bogus"}} =
               perform_job(EmailVerificationEmail, %{
                 "user_id" => Ecto.UUID.generate(),
                 "encrypted_token" => TokenCipher.encrypt("irrelevant"),
                 "context" => "bogus"
               })
    end
  end

  describe "Mailer.send_email_verification_email/2 enqueue" do
    test "enqueues a job carrying user_id, encrypted token, and context" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Accounts.generate_email_verification(user, :no_rate_limit)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{} = job} =
                 Mailer.send_email_verification_email(user, :welcome)

        assert job.worker == "Malan.Workers.EmailVerificationEmail"
        assert job.queue == "mailers"
        args = for {k, v} <- job.args, into: %{}, do: {to_string(k), v}
        assert args["user_id"] == user.id
        assert args["context"] == "welcome"
        refute Map.has_key?(args, "token")
        assert is_binary(args["encrypted_token"])
        refute args["encrypted_token"] =~ user.email_verification_token
        assert {:ok, plaintext} = TokenCipher.decrypt(args["encrypted_token"])
        assert plaintext == user.email_verification_token
      end)
    end
  end
end
