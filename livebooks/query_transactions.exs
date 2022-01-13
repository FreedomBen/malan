alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.{User, Transaction}

require Ecto.Query  # So we can use the `from` macro

# Retrieve the Count of Transactions
Ecto.Query.from(t in Transaction, select: count(t.id))
|> Repo.one()

