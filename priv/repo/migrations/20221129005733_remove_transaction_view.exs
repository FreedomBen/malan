defmodule Malan.Repo.Migrations.RemoveTransactionView do
  use Ecto.Migration

  def up do
    execute("DROP VIEW transactions;")
  end

  def down do
    execute("CREATE VIEW transactions AS SELECT * FROM logs;")
  end
end
