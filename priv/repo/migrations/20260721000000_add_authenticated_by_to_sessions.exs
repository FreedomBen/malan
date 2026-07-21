defmodule Malan.Repo.Migrations.AddAuthenticatedByToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      # How the session was authenticated: "password", "password+totp", or
      # "password+backup_code". The DB default backfills existing rows and
      # covers inserts from pre-MFA code during a rolling deploy — password
      # was the only login method for both.
      add :authenticated_by, :string, null: false, default: "password"
    end
  end
end
