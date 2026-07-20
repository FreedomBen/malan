defmodule Malan.Repo.Migrations.CreateTotpBackupCodes do
  use Ecto.Migration

  def change do
    create table(:totp_backup_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # Utils.Crypto.hash_token/1 of the normalized code; plaintext shown once
      add :code_hash, :string, null: false
      # nil = unused; set once when the code is spent (single-use)
      add :used_at, :utc_datetime, default: nil, null: true
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:totp_backup_codes, [:user_id])
  end
end
