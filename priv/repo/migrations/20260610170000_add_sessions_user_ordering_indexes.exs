defmodule Malan.Repo.Migrations.AddSessionsUserOrderingIndexes do
  use Ecto.Migration

  # Concurrent index builds cannot run inside a transaction.
  @disable_ddl_transaction true
  @disable_migration_lock true

  # Session list queries filter by user_id and order by
  # (inserted_at DESC, id DESC). The only index on user_id is a hash
  # index, which cannot help the sort, so every listing sorts that
  # user's full session set. The composite index serves the filter and
  # the sort together. The partial index serves the active-session
  # queries — list_active_sessions/3 and revoke_active_sessions/2 (the
  # latter runs on every password change) — which filter
  # user_id + revoked_at IS NULL.
  def up do
    create index(:sessions, ["user_id", "inserted_at DESC", "id DESC"],
             name: :sessions_user_ins_desc_idx,
             concurrently: true
           )

    create index(:sessions, ["user_id", "inserted_at DESC"],
             name: :sessions_active_user_idx,
             where: "revoked_at IS NULL",
             concurrently: true
           )
  end

  def down do
    drop index(:sessions, [:user_id],
           name: :sessions_user_ins_desc_idx,
           concurrently: true
         )

    drop index(:sessions, [:user_id],
           name: :sessions_active_user_idx,
           concurrently: true
         )
  end
end
