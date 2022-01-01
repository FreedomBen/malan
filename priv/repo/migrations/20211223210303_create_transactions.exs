defmodule Malan.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type_enum, :smallint, null: false
      add :verb_enum, :smallint, null: false
      add :when, :utc_datetime, null: false
      add :what, :string, null: false
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id), null: true
      add :session_id, references(:sessions, on_delete: :nothing, type: :binary_id), null: true
      add :who, references(:users, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:session_id])
    create index(:transactions, [:who])
  end
end
