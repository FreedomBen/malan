defmodule Malan.Repo.Migrations.AddLocksToUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users, primary_key: false) do
      add :locked_at, :utc_datetime, null: true, default: nil
      add :locked_by, references(:users, on_delete: :nothing, type: :binary_id), null: true
    end

    create index(:users, [:locked_by], using: :hash)
  end
end
