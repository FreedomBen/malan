defmodule Malan.Repo.Migrations.CreatePhoneNumbers do
  use Ecto.Migration

  def change do
    create table(:phone_numbers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :primary, :boolean, default: false, null: false
      add :number, :string
      add :verified_at, :utc_datetime, default: nil, null: true
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:phone_numbers, [:user_id])
    create index(:phone_numbers, [:number])
  end
end
