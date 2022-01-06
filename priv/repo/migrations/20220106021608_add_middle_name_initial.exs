defmodule Malan.Repo.Migrations.AddMiddleNameInitial do
  use Ecto.Migration

  def change do
    alter table("users") do
      # suffix can be arbitrary:  https://en.wikipedia.org/wiki/Suffix_(name)
      # prfix can be arbitrary:  https://findanyanswer.com/what-does-name-prefix-mean
      add :middle_name, :string, null: false, default: ""
      add :name_suffix, :string, null: false, default: ""
      add :name_prefix, :string, null: false, default: ""
      add :display_name, :string, null: false, default: ""
    end
  end
end
