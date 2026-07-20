defmodule Malan.Repo.Migrations.CreateUserTotps do
  use Ecto.Migration

  def change do
    create table(:user_totps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # NimbleTOTP secret encrypted by Malan.Accounts.TotpCipher; key_id
      # records which TOTP_ENCRYPTION_KEYS entry encrypted it (rotation support).
      add :secret, :binary, null: false
      add :key_id, :integer, null: false
      # nil = enrollment pending (inert until the user confirms with a code)
      add :confirmed_at, :utc_datetime, default: nil, null: true
      # Unix seconds of the last accepted TOTP step's start (step-aligned).
      # bigint: int4 overflows in 2038. nil until confirm seeds it.
      add :last_used_ts, :bigint, default: nil, null: true
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_totps, [:user_id])
  end
end
