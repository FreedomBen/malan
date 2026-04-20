defmodule Malan.Repo.Migrations.RenameLogsPkey do
  use Ecto.Migration

  # The primary key on `logs` is still named `transactions_pkey` from
  # when the table was renamed from `transactions` to `logs`. Renaming
  # the constraint is purely cosmetic but keeps the schema tidy and
  # avoids confusion when reading pg_stat_* output. In PostgreSQL,
  # renaming the PK constraint also renames the underlying index.
  #
  # This is a metadata-only change — it takes a brief ACCESS EXCLUSIVE
  # lock on `logs` but does no I/O, so it is safe to run inside the
  # default migration transaction.
  def up do
    execute(
      "ALTER TABLE logs RENAME CONSTRAINT transactions_pkey TO logs_pkey",
      "ALTER TABLE logs RENAME CONSTRAINT logs_pkey TO transactions_pkey"
    )
  end
end
