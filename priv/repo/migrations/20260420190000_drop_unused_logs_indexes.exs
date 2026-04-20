defmodule Malan.Repo.Migrations.DropUnusedLogsIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # The `logs` table inherited three btree indexes from the days when it
  # was called `transactions`:
  #   - transactions_user_id_index   (~959 MB)
  #   - transactions_session_id_index (~955 MB)
  #   - transactions_who_index       (~890 MB)
  #
  # Each had idx_scan = 0 in prod pg_stat_user_indexes — no query planner
  # is using them for reads, but every INSERT still pays to update them.
  # Random-UUID btree pages also bloat aggressively on insert. Dropping
  # them cuts write amplification on the hot log-insert path roughly in
  # half.
  #
  # The primary key (transactions_pkey) and logs_inserted_at_index are
  # still needed and left alone. A future migration renames the pkey to
  # `logs_pkey`.
  def up do
    drop_if_exists index(:logs, [:user_id],
                     name: :transactions_user_id_index,
                     concurrently: true
                   )

    drop_if_exists index(:logs, [:session_id],
                     name: :transactions_session_id_index,
                     concurrently: true
                   )

    drop_if_exists index(:logs, [:who],
                     name: :transactions_who_index,
                     concurrently: true
                   )
  end

  def down do
    create index(:logs, [:user_id],
             name: :transactions_user_id_index,
             concurrently: true
           )

    create index(:logs, [:session_id],
             name: :transactions_session_id_index,
             concurrently: true
           )

    create index(:logs, [:who],
             name: :transactions_who_index,
             concurrently: true
           )
  end
end
