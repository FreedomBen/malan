defmodule Malan.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :api_token_hash, :string, null: false
      add :expires_at, :utc_datetime
      add :authenticated_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :ip_address, :string, null: false
      add :location, :string
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:sessions, [:user_id], using: :hash)
    create index(:sessions, [:api_token_hash], using: :hash)
  end
end
