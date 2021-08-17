defmodule Malan.Repo.Migrations.AddPasswordResetTokenIndex do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:password_reset_token_hash], using: :btree)
  end
end
