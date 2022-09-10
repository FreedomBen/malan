require Ecto.Query  # So we can use the `from` macro

import Ecto.Query, only: [from: 2] # So we can use the from macro directly

alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.{User, Session, Transaction}

#from(u in User, select: count(u.id))
from(u in User, where: not is_nil(u.birthday), limit: 10)
|> Repo.all()

from(u in User, select: count(u.id), where: not is_nil(u.birthday))
|> Repo.one()

from(u in User, select: {u.id, u.email, u.birthday}, where: not is_nil(u.birthday), limit: 10)
|> Repo.all()
