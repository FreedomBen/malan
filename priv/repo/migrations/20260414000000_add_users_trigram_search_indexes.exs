defmodule Malan.Repo.Migrations.AddUsersTrigramSearchIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Admin UI search runs ILIKE '%term%' against five user columns. Plain btree
  # indexes can't serve double-wildcard matches, so searches degrade to a full
  # sequential scan. pg_trgm + GIN indexes turn substring ILIKE/LIKE into index
  # scans. CONCURRENTLY avoids locking the users table during index build.
  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS users_username_trgm_index
      ON users USING GIN (username gin_trgm_ops)
    """

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS users_email_trgm_index
      ON users USING GIN (email gin_trgm_ops)
    """

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS users_display_name_trgm_index
      ON users USING GIN (display_name gin_trgm_ops)
    """

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS users_first_name_trgm_index
      ON users USING GIN (first_name gin_trgm_ops)
    """

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS users_last_name_trgm_index
      ON users USING GIN (last_name gin_trgm_ops)
    """
  end

  def down do
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_username_trgm_index"
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_email_trgm_index"
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_display_name_trgm_index"
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_first_name_trgm_index"
    execute "DROP INDEX CONCURRENTLY IF EXISTS users_last_name_trgm_index"
    # Extension left in place — it may be used by other indexes/queries.
  end
end
