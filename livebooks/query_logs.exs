require Ecto.Query  # So we can use the `from` macro

import Ecto.Query, only: [from: 2] # So we can use the from macro directly

alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.{User, Session, Log}

# Retrieve the Count of Logs
Ecto.Query.from(t in Log, select: count(t.id))
|> Repo.one()

# Retrieve 5 oldest logs
from(t in Log, select: t, limit: 5, order_by: t.inserted_at)
|> Repo.all()

# Retrieve 5 most recent logs
from(t in Log, select: t, limit: 5, order_by: [desc_nulls_last: t.inserted_at])
|> Repo.all()
