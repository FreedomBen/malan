defmodule Malan.Repo.Migrations.AddWhoUsernameToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :who_username, :string, null: true
    end
  end
end
