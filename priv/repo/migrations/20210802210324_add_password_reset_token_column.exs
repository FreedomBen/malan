defmodule Malan.Repo.Migrations.AddPasswordResetTokenColumn do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :password_reset_token_hash, :string, null: true, default: nil
    end
  end
end
