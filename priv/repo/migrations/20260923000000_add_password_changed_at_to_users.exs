defmodule Malan.Repo.Migrations.AddPasswordChangedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # When the password hash was last replaced. Deliberately not
      # backfilled: NULL means the password predates tracking — inserted_at
      # would overstate the age for anyone who changed their password after
      # registering, and updated_at bumps on any profile edit.
      add :password_changed_at, :utc_datetime
    end
  end
end
