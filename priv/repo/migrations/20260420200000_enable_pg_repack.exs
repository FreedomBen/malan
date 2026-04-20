defmodule Malan.Repo.Migrations.EnablePgRepack do
  use Ecto.Migration

  # Enables the pg_repack extension so tables can be rebuilt online
  # (minimal locks) to reclaim bloat. The `logs` table has accumulated
  # tens of GB of dead-tuple bloat from archiver deletes that
  # autovacuum cannot reclaim, and VACUUM FULL would take an
  # ACCESS EXCLUSIVE lock for the full runtime.
  #
  # Migrations run as doadmin on DigitalOcean managed PG, which is the
  # role that can CREATE EXTENSION. The app role `malan` does not need
  # any privilege on the extension itself — the pg_repack client
  # connects as doadmin from the operator's host.
  #
  # CREATE EXTENSION is idempotent with IF NOT EXISTS, so this is safe
  # to re-run.
  def up do
    execute(
      "CREATE EXTENSION IF NOT EXISTS pg_repack",
      "DROP EXTENSION IF EXISTS pg_repack"
    )
  end
end
