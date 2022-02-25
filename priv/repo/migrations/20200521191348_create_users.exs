defmodule Malan.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext",
            "DROP EXTENSION citext"

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :citext, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :nick_name, :string, null: false, default: ""
      add :password_hash, :string, null: false
      add :email, :citext, null: false
      add :email_verified, :utc_datetime
      add :roles, {:array, :string}, null: false, default: []
      add :preferences, :map, null: false, default: %{}
      add :latest_tos_accept_ver, :smallint, null: true, default: nil
      add :latest_pp_accept_ver, :smallint, null: true, default: nil
      add :tos_accept_events, :map, null: false, default: []
      add :privacy_policy_accept_events, :map, null: false, default: []
      add :deleted_at, :utc_datetime, null: true, default: nil
      add :birthday, :utc_datetime, null: true, default: nil
      add :weight, :decimal, null: true, default: nil
      add :height, :decimal, null: true, default: nil
      add :race_enum, {:array, :integer}, null: true, default: nil
      add :ethnicity_enum, :integer, null: true, default: nil
      add :sex_enum, :integer, null: true, default: nil
      add :gender_enum, :integer, null: true, default: nil

      timestamps(type: :utc_datetime)
    end

    # Want hash indexes, but Ecto unique constraint only works with btree
    create unique_index(:users, [:username], using: :btree)
    create unique_index(:users, [:email], using: :btree)
  end
end
