defmodule Malan.Repo.Migrations.AddEmailVerificationFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_verification_token_hash, :string, null: true, default: nil
      add :email_verification_token_expires_at, :utc_datetime, null: true, default: nil
      add :email_verification_sent_at, :utc_datetime, null: true, default: nil
    end

    create unique_index(:users, [:email_verification_token_hash], using: :btree)
  end
end
