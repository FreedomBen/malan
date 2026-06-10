defmodule Malan.Repo.Migrations.DropSessionsUserIdHashIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # After 20260610170000_add_sessions_user_ordering_indexes, the hash
  # index on sessions.user_id is redundant: the composite
  # sessions_user_ins_desc_idx covers user_id equality lookups and the
  # partial sessions_active_user_idx covers the active-session filter.
  # Keeping it costs index-update overhead on every login (session
  # insert). Migration order guarantees create-before-drop; deploy and
  # verify the new indexes on staging before this reaches prod.
  def up do
    drop_if_exists index(:sessions, [:user_id],
                     name: :sessions_user_id_index,
                     concurrently: true
                   )
  end

  def down do
    create index(:sessions, [:user_id],
             name: :sessions_user_id_index,
             using: :hash,
             concurrently: true
           )
  end
end
