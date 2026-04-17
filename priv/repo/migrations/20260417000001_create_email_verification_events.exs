defmodule Malan.Repo.Migrations.CreateEmailVerificationEvents do
  use Ecto.Migration

  def change do
    create table(:email_verification_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false
      add :email, :string, null: false
      add :token_hash, :string, null: true
      add :event_type, :string, null: false
      add :ip, :string, null: true
      add :user_agent, :string, null: true

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:email_verification_events, [:user_id])
    create index(:email_verification_events, [:event_type])
    create index(:email_verification_events, [:inserted_at])
  end
end
