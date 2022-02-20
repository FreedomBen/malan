defmodule Malan.Repo.Migrations.AddSuccessToTransactions do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add :success, :boolean, null: false
    end
  end
end
