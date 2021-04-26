defmodule Malan.Repo.Migrations.AddJsonBlobToUsers do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :custom_attrs, :map, null: true, default: %{}
    end
  end
end
