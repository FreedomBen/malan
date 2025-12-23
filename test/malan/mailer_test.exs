defmodule Malan.MailerTest do
  # use ExUnit.Case, async: false
  use Malan.DataCase, async: true

  # alias Malan.Test.Utils, as: TestUtils
  alias Malan.Test.Helpers
  alias Malan.Mailer

  describe "UserNotifier" do
    test "Sends mail" do
      {:ok, user} = Helpers.Accounts.regular_user()
      {:ok, user} = Malan.Accounts.generate_password_reset(user, :no_rate_limit)
      email = MalanWeb.UserNotifier.password_reset_email(user)
      Mailer.deliver(email)
      Swoosh.TestAssertions.assert_email_sent(email)

      # alias Swoosh.Email
      # import Swoosh.TestAssertions

      # email = Email.new(subject: "Hello, Avengers!")
      # Swoosh.Adapters.Test.deliver(email, [])

      ## assert a specific email was sent
      # assert_email_sent(email)

      # assert an email with specific field(s) was sent
      # assert_email_sent(subject: "Hello, Avengers!")

      # assert an email that satisfies a condition
      # assert_email_sent(fn email ->
      #  assert length(email.to) == 2
      # end)
    end
  end
end
