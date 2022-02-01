alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.User

# Retrieve the user's ID
%User{id: user_id} = user = Accounts.get_user_by(email: "email@example.com")

# Change user's password
Accounts.update_user(user, %{"password" => "2YzMtYzdmN2"})

# Lock the user's account
Accounts.lock_user(user, nil)
