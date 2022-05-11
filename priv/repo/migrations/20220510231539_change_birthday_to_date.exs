defmodule Malan.Repo.Migrations.ChangeBirthdayToDate do
  use Ecto.Migration

  def change do
    alter table("users") do
      modify :birthday, :date, from: :utc_datetime
    end
  end
end
