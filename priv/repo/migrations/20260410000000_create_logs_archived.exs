defmodule Malan.Repo.Migrations.CreateLogsArchived do
  use Ecto.Migration

  def up do
    create table(:logs_archived, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type_enum, :integer, null: false
      add :verb_enum, :integer, null: false
      add :when, :utc_datetime, null: false
      add :what, :text, null: false
      add :user_id, :binary_id
      add :session_id, :binary_id
      add :who, :binary_id
      add :who_username, :string
      add :success, :boolean
      add :changeset, :map, null: false, default: %{}
      add :remote_ip, :string, null: false

      timestamps(type: :utc_datetime)
    end

    # Minimal indexes — this table is for compliance/forensics reads only
    create index(:logs_archived, [:inserted_at])
    create index(:logs_archived, [:user_id])
    create index(:logs_archived, [:who])
  end

  def down do
    drop table(:logs_archived)
  end
end
