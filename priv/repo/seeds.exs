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

root =
  User.registration_changeset(%User{}, %{
    username: "root",
    first_name: "Root",
    last_name: "User",
    password: "password10",
    email: "root@example.com",
    roles: ["admin", "user"],
    sex: "male",
    birthday: ~U[1983-06-13 01:09:08.105179Z]
  })

Malan.Repo.insert!(root, on_conflict: :nothing, conflict_target: :username)

# Promote root user to admin (currently the role gets stripped on create.  See #7)
Accounts.get_user_by(username: "root")
|> Accounts.admin_update_user(%{roles: ["admin", "user"]})

#ben = User.registration_changeset(%User{}, %{
#  username: "ben",
#  first_name: "Ben",
#  last_name: "Johnson",
#  password: "password10",
#  email: "ben@example.com",
#  roles: ["moderator", "user"],
#  sex: "male",
#  birthday: ~U[1983-06-13 01:09:08.105179Z]
#})
#Malan.Repo.insert!(ben, on_conflict: :nothing, conflict_target: :username)
#
#van = User.registration_changeset(%User{}, %{
#  username: "van",
#  first_name: "Van",
#  last_name: "Johnson",
#  password: "password10",
#  email: "vanessa@example.com",
#  roles: ["user"],
#  sex: "female",
#  birthday: ~U[1986-06-13 01:19:08.105179Z]
#})
#Malan.Repo.insert!(van)
#Malan.Repo.insert!(van, on_conflict: :nothing, conflict_target: :username)

