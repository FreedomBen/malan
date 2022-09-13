# Run with:  mix run scripts/mixrun/test-password.exs

alias Malan.Accounts
alias Malan.Accounts.{User, Session}

username = "passwordresetuser"
password = "password12"

defmodule Print do
  def puts_green(msg) do
    IO.puts(IO.ANSI.format([:green, msg, :reset]))
  end

  def puts_red(msg) do
    IO.puts(IO.ANSI.format([:red, msg, :reset]))
  end

  def inspect_green(obj) do
    IO.puts(IO.ANSI.format([:green]))
    IO.inspect(obj)
    IO.puts(IO.ANSI.format([:reset]))
  end

  def inspect_red(obj) do
    IO.puts(IO.ANSI.format([:red]))
    IO.inspect(obj)
    IO.puts(IO.ANSI.format([:reset]))
  end
end

case Accounts.create_session(username, password, "1.1.1.1", %{"ip_address" => "1.1.1.1"}) do
  {:ok, %Session{} = session} ->
    Print.puts_green("Successfully created session (logged in)")
    Print.inspect_green(session)

  {:error, error} ->
    Print.puts_red("Error encountered creating session")
    Print.inspect_red(error)
end
