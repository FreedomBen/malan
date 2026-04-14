# Load home iex config file if exists
import_file_if_available("~/.iex.exs")

require Ecto.Query
import Ecto.Query, only: [from: 2]

alias Malan.{
  Repo,
  Accounts
}

alias Malan.Accounts.{User, Session, Transaction}

import_if_available(Ecto.Query)
import_if_available(Ecto.Changeset)

Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:postgrex)

# Start Malan.Repo if it's not already up
case Process.whereis(Malan.Repo) do
  nil ->
    IO.puts("Repo not started — starting it for you")
    Malan.Repo.start_link()
  _ ->
    :ok
end

