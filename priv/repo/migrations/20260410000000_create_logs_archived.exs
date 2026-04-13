defmodule Malan.Repo.Migrations.CreateLogsArchived do
  use Ecto.Migration

  def up do
    create table(:logs_archived, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type_enum, :integer, null: false
      add :verb_enum, :integer, null: false
      add :when, :utc_datetime, null: false
      add :what, :text, null: false
      add :user_id, :binary_id
      add :session_id, :binary_id
      add :who, :binary_id
      add :who_username, :string
      add :success, :boolean
      add :changeset, :map, null: false, default: %{}
      add :remote_ip, :string, null: false

      timestamps(type: :utc_datetime)
    end

    # Initial index set. Superseded by 20260413160000_optimize_logs_archived_indexes
    # which drops the random-UUID btrees (write-amplification with near-zero read
    # benefit for a rarely-queried archive) and swaps inserted_at to BRIN.
    create index(:logs_archived, [:inserted_at])
    create index(:logs_archived, [:user_id])
    create index(:logs_archived, [:who])
  end

  def down do
    drop table(:logs_archived)
  end
end
