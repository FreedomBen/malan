alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.User

# Retrieve the user's ID
%User{id: user_id} = user = Accounts.get_user_by(email: "email@example.com")

# Change user's password
deleted_user = Accounts.delete_user(user)
