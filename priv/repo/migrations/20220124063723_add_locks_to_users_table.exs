defmodule Malan.Repo.Migrations.AddLocksToUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users, primary_key: false) do
      add :locked_at, :utc_datetime, null: true, default: nil
      add :locked_by, :string, null: true, default: nil
    end
  end
end
