defmodule Malan.Repo.Migrations.CreateAddresses do
  use Ecto.Migration

  def change do
    create table(:addresses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :primary, :boolean, default: false, null: false
      add :verified_at, :utc_datetime, default: nil, null: true
      add :name, :string
      add :line_1, :string
      add :line_2, :string
      add :country, :string
      add :city, :string
      add :state, :string
      add :postal, :string
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id, null: false)

      timestamps(type: :utc_datetime)
    end

    create index(:addresses, [:user_id])
  end
end
