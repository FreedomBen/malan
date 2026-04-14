alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.User

# Retrieve the user's ID
%User{id: user_id} = user = Accounts.get_user_by(email: "email@example.com")

# Add the admin role
{:ok, updated} = Accounts.user_add_role("admin", user_id)

# Inspect results
IO.inspect(updated, label: "After")
IO.inspect(updated.roles, label: "Roles")
