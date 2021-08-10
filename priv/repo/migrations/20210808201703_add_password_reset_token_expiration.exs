defmodule Malan.Repo.Migrations.AddPasswordResetTokenExpiration do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :password_reset_token_expires_at, :utc_datetime, null: true, default: nil
    end
  end
end
