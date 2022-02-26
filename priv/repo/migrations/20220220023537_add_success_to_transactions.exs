defmodule Malan.Repo.Migrations.AddSuccessToTransactions do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add :success, :boolean, null: true
    end
  end

  # Initially we were going to require non-null but initialize existing records:
  #
  # def up do
  #   alter table(:transactions) do
  #     add :success, :boolean, default: true, null: false
  #   end
  #
  #   alter table(:transactions) do
  #     modify :success, :boolean, default: nil, null: false
  #   end
  # end

  # def down do
  #   alter table(:transactions) do
  #     remove :success,  :boolean, null: false
  #   end
  # end
end
