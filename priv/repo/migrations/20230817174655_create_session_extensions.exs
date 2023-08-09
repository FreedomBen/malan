defmodule Malan.Repo.Migrations.CreateSessionExtensions do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:session_extensions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :old_expires_at, :utc_datetime
      add :new_expires_at, :utc_datetime
      add :extended_by_seconds, :integer
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :session_id, references(:sessions, on_delete: :nothing, type: :binary_id)
      add :extended_by_user, references(:users, on_delete: :nothing, type: :binary_id)
      add :extended_by_session, references(:sessions, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:session_extensions, [:session_id])

    ## This will be often written, rarely read, and tables might get pretty big,
    ## so we won't include indexes on these fields even though normally we would
    # create_if_not_exists index(:session_extensions, [:user_id])
    # create_if_not_exists index(:session_extensions, [:extended_by_user])
    # create_if_not_exists index(:session_extensions, [:extended_by_session])
  end
end
