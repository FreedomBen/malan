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
  #
  # If the pg_repack shared library is not installed on the server
  # (e.g. local dev, CI, or a managed PG plan that does not bundle it),
  # CREATE EXTENSION fails with 58P01 (undefined_file). We probe
  # pg_available_extensions first and skip with a NOTICE so the
  # migration does not block environments that lack the library.
  def up do
    execute(
      """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_repack') THEN
          CREATE EXTENSION IF NOT EXISTS pg_repack;
        ELSE
          RAISE NOTICE 'pg_repack not available on this server; skipping CREATE EXTENSION';
        END IF;
      END
      $$;
      """,
      "DROP EXTENSION IF EXISTS pg_repack"
    )
  end
end
