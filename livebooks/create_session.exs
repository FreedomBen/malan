alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.User

# Retrieve the user's ID
%User{id: user_id} = user = Accounts.get_user_by(email: "email@example.com")

# Use the user ID to create a new session (API token)
Accounts.new_session(%{"user_id" => user_id, "ip_address" => "127.0.0.1"})
