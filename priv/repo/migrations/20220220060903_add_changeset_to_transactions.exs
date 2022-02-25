defmodule Malan.Repo.Migrations.AddChangesetToTransactions do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add :changeset, :map, null: false, default: %{}
    end
  end
end
