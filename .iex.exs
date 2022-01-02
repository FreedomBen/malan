# Load home iex config file if exists
import_file_if_available("~/.iex.exs")


alias Malan.{
  Repo,
  Accounts
}

alias Malan.Accounts.{User, Session, Transaction}

import_if_available Ecto.Query
import_if_available Ecto.Changeset
