require Ecto.Query  # So we can use the `from` macro

import Ecto.Query, only: [from: 2] # So we can use the from macro directly

alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.{User, Session, Transaction}

# Retrieve the user's ID
%User{id: user_id} = user = Accounts.get_user_by(email: "email@example.com")

# Use the user ID to create a new session (API token)
Accounts.new_session(%{"user_id" => user_id, "ip_address" => "127.0.0.1"})


# Count number of sessions with a real_ip_address
Repo.one(from(s in Session, select: count(s.id), where: not is_nil(s.real_ip_address)))
