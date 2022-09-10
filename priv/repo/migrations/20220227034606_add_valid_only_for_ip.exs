defmodule Malan.Repo.Migrations.AddValidOnlyForIp do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :valid_only_for_ip, :boolean, null: false, default: false
    end
  end
end
