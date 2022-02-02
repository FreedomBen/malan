defmodule Malan.MailerTest do
  #use ExUnit.Case, async: false
  use Malan.DataCase, async: true

  alias Malan.Accounts
  #alias Malan.Test.Utils, as: TestUtils
  alias Malan.Test.Helpers
  alias Malan.Mailer

  describe "Malan.Pagination.PageOutOfBounds" do
    test "Sends mail" do
      {:ok, user} = Helpers.Accounts.regular_user()
      email = Accounts.UserEmail.password_reset(user)
      #Swoosh.Adapters.Test.deliver(email, [])
      Mailer.deliver(email)
      Swoosh.TestAssertions.assert_email_sent(email)




      #alias Swoosh.Email
      #import Swoosh.TestAssertions

      #email = Email.new(subject: "Hello, Avengers!")
      #Swoosh.Adapters.Test.deliver(email, [])

      ## assert a specific email was sent
      #assert_email_sent(email)

      # assert an email with specific field(s) was sent
      #assert_email_sent(subject: "Hello, Avengers!")

      # assert an email that satisfies a condition
      #assert_email_sent(fn email ->
      #  assert length(email.to) == 2
      #end)

    end
  end
end
