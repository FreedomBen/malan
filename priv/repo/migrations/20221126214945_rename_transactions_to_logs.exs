defmodule Malan.Repo.Migrations.RenameTransactionsToLogs do
  use Ecto.Migration

  def up do
    rename table(:transactions), to: table(:logs)

    # Create a view to preserve backwards compatiblity while running
    execute("CREATE VIEW transactions AS SELECT * FROM logs;")
  end

  def down do
    rename table(:logs), to: table(:transactions)

    execute("DROP VIEW transactions;")
  end
end
