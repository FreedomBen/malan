defmodule Malan.Repo.Migrations.OptimizeLogsArchivedIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # The archive table is append-only with no API reading from it — the only
  # queries are rare forensic / compliance lookups. Random-UUID btree indexes
  # on user_id and who cost write amplification on every insert but almost
  # never pay it back on reads. A BRIN index on inserted_at keeps time-range
  # scans fast at a fraction of the write cost of a btree.
  def up do
    drop_if_exists index(:logs_archived, [:user_id], concurrently: true)
    drop_if_exists index(:logs_archived, [:who], concurrently: true)
    drop_if_exists index(:logs_archived, [:inserted_at], concurrently: true)

    create index(:logs_archived, [:inserted_at],
             name: :logs_archived_inserted_at_brin_index,
             using: "BRIN",
             concurrently: true
           )
  end

  def down do
    drop_if_exists index(:logs_archived, [:inserted_at],
                     name: :logs_archived_inserted_at_brin_index,
                     concurrently: true
                   )

    create index(:logs_archived, [:inserted_at], concurrently: true)
    create index(:logs_archived, [:user_id], concurrently: true)
    create index(:logs_archived, [:who], concurrently: true)
  end
end
