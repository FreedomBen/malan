defmodule Malan.Repo.Migrations.AddRemoteIpToTransaction do
  use Ecto.Migration

  # Remote IP will be a required filed that can't be null and won't have
  # a default.  But we need existing records to default to ""
  def up do
    # Add column, defaulting existing records to ""
    alter table(:transactions) do
      add :remote_ip, :string, default: "", null: false
    end
  
    # Modify column to have a default of "nil" (basically removing the default)
    alter table(:transactions) do
      modify :remote_ip, :string, default: nil, null: false
    end
  end

  def down do
    alter table(:transactions) do
      remove :remote_ip, :string, null: false
    end
  end
end
