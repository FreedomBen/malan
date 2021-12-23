defmodule Malan.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string
      add :verb, :string
      add :when, :utc_datetime
      add :what, :string
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :session_id, references(:sessions, on_delete: :nothing, type: :binary_id)
      add :who, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:session_id])
    create index(:transactions, [:who])
  end
end
