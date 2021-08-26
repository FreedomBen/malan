# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Malan.Accounts
alias Malan.Accounts.User

Malan.Repo.insert_all(
  Malan.Accounts.User,
  [
    %{
      username: "User1",
      email: "User1@Example.com",
      password_hash: "password12345",
      first_name: "User1",
      last_name: "User1",
      inserted_at: Malan.Utils.DateTime.utc_now_trunc(),
      updated_at: Malan.Utils.DateTime.utc_now_trunc()
    },
    %{
      username: "User2",
      email: "User2@Example.com",
      password_hash: "password12345",
      first_name: "User2",
      last_name: "User2",
      inserted_at: Malan.Utils.DateTime.utc_now_trunc(),
      updated_at: Malan.Utils.DateTime.utc_now_trunc()
    }
  ]
)

