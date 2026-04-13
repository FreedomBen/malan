defmodule Malan.Repo.Migrations.AddLogsInsertedAtIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create index(:logs, [:inserted_at], concurrently: true)
  end

  def down do
    drop index(:logs, [:inserted_at], concurrently: true)
  end
end
