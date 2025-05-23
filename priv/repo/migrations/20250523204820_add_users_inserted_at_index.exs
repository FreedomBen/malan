defmodule Malan.Repo.Migrations.AddUsersInsertedAtIndex do
  use Ecto.Migration

  def change do
    create index(:users, [:inserted_at])
  end
end
