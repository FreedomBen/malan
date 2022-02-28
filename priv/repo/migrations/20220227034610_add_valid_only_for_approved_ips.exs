defmodule Malan.Repo.Migrations.AddValidOnlyForApprovedIps do
  use Ecto.Migration

  def change do
    alter table(:sesions) do
      add :valid_only_for_approved_ips, :boolean, null: false, default: false
    end
  end
end
