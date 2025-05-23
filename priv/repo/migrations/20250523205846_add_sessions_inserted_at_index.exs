defmodule Malan.Repo.Migrations.AddSessionsInsertedAtIndex do
  use Ecto.Migration

  def change do
    create index(:sessions, [:inserted_at])
  end
end
