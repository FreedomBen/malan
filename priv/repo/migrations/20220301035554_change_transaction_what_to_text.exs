defmodule Malan.Repo.Migrations.ChangeTransactionWhatToText do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      modify :what, :text, null: false
    end
  end
end
