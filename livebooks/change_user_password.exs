alias Malan.Repo
alias Malan.Accounts
alias Malan.Accounts.User

# Retrieve the user's ID
%User{id: user_id} = user = Accounts.get_user_by(email: "email@example.com")
%User{id: user_id} = user = Accounts.get_user_by(email: "bradleyc61@yahoo.com")
%User{id: user_id} = u3 = Accounts.get_user_by(email: "chloeray_05@yahoo.com")

# Change user's password
Accounts.update_user(user, %{"password" => "2YzMtYzdmN2"})

# Lock the user's account
Accounts.lock_user(user, nil)
