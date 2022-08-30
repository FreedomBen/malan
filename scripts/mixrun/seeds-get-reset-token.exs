# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Malan.Repo.insert!(%Malan.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Malan.Accounts
alias Malan.Accounts.User

username = "passwordresetuser"
email = "pru@example.com"

User.registration_changeset(%User{}, %{
  username: username,
  first_name: "Password Reset",
  last_name: "User",
  password: "password10",
  email: email,
  roles: ["user"],
  sex: "male",
  birthday: ~U[1983-06-13 01:09:08.105179Z]
})
|> Malan.Repo.insert!(on_conflict: :nothing, conflict_target: :username)

{:ok, user} =
  Accounts.get_user_by_id_or_username(username)
  |> Accounts.generate_password_reset(:no_rate_limit)

IO.puts("Password reset token for #{user.username} (#{user.email}):  #{user.password_reset_token}")
IO.puts("http://192.168.2.2:4000/users/reset_password/#{user.password_reset_token}")
