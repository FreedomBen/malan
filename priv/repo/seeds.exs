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

#alias Malan.Accounts
alias Malan.Accounts.User

ben = User.registration_changeset(%User{}, %{
  username: "ben",
  first_name: "Ben",
  last_name: "Johnson",
  password: "password10",
  email: "ben@ace.io",
  roles: ["admin", "user"],
  sex: "male",
  birthday: ~U[1986-06-13 01:09:08.105179Z]
})
Malan.Repo.insert!(ben)

van = User.registration_changeset(%User{}, %{
  username: "van",
  first_name: "Van",
  last_name: "Johnson",
  password: "password10",
  email: "vanessa@ace.io",
  roles: ["user"],
  sex: "female",
  birthday: ~U[1986-06-13 01:19:08.105179Z]
})
Malan.Repo.insert!(van)

### Ingredients
#Ingredients.create_ingredient("parnsips")
